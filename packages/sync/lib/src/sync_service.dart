import 'dart:async';

import 'package:domain/domain.dart';
import 'package:persistence/persistence.dart';

import 'sync_state.dart';

abstract interface class SyncTransport {
  Future<UploadResult> upload(List<LearningEvent> events);

  Future<DownloadResult> download({required SyncCursor cursor});
}

abstract interface class SyncService {
  Stream<SyncState> get state;

  Future<SyncResult> syncNow();

  Future<void> scheduleBackgroundSync();
}

class LocalSyncService implements SyncService {
  LocalSyncService({
    required this.repository,
    required this.transport,
    DateTime Function()? clock,
  }) : _clock = clock ?? (() => DateTime.now().toUtc());

  final LocalLearningRepository repository;
  final SyncTransport transport;
  final DateTime Function() _clock;
  final StreamController<SyncState> _states =
      StreamController<SyncState>.broadcast();
  DateTime? _lastSuccessfulSync;
  Future<void>? _scheduledSync;

  @override
  Stream<SyncState> get state async* {
    final pending = await repository.pendingEvents();
    yield SyncState(
      status: pending.isEmpty ? SyncStatus.localOnly : SyncStatus.pending,
      pendingCount: pending.length,
      lastSuccessfulSync: _lastSuccessfulSync,
      retry: syncNow,
    );
    yield* _states.stream;
  }

  @override
  Future<SyncResult> syncNow() async {
    final pending = await repository.pendingEvents();
    if (pending.isNotEmpty) {
      _emit(SyncState(
        status: SyncStatus.pending,
        pendingCount: pending.length,
        lastSuccessfulSync: _lastSuccessfulSync,
        retry: syncNow,
      ));
    }

    try {
      final upload = pending.isEmpty
          ? UploadResult(acknowledgedIds: const [])
          : await transport.upload(List<LearningEvent>.unmodifiable(pending));
      final cursor = await readCursor();
      final download = await transport.download(cursor: cursor);
      await repository.commitSyncBatch(
        downloadedEvents: download.events,
        acknowledgedIds: upload.acknowledgedIds,
        uploadedAt: _clock(),
        cursor: download.nextCursor.value,
      );

      _lastSuccessfulSync = _clock();
      final remaining = await repository.pendingEvents();
      _emit(SyncState(
        status: remaining.isEmpty ? SyncStatus.synced : SyncStatus.pending,
        pendingCount: remaining.length,
        lastSuccessfulSync: _lastSuccessfulSync,
        retry: syncNow,
      ));
      return SyncResult(
        status: remaining.isEmpty ? SyncStatus.synced : SyncStatus.pending,
        uploadedCount: upload.acknowledgedIds.length,
        downloadedCount: download.events.length,
      );
    } on SyncTransportUnavailable {
      return _failure(SyncStatus.offline);
    } catch (_) {
      return _failure(SyncStatus.error);
    }
  }

  Future<SyncResult> _failure(SyncStatus status) async {
      final remaining = await repository.pendingEvents();
      const message = 'Sync failed. Progress remains saved locally; retry when online.';
      _emit(SyncState(
        status: status,
        pendingCount: remaining.length,
        lastSuccessfulSync: _lastSuccessfulSync,
        message: message,
        retry: syncNow,
      ));
      return SyncResult(status: status, message: message);
  }

  @override
  Future<void> scheduleBackgroundSync() {
    return _scheduledSync ??= syncNow().then<void>((_) {
      _scheduledSync = null;
    });
  }

  Future<SyncCursor> readCursor() async {
    final rows = await repository.database.select(
      'SELECT value FROM sync_cursor WHERE key = ?',
      ['events'],
    );
    return rows.isEmpty
        ? SyncCursor.initial
        : SyncCursor.fromValue(rows.single['value']! as String);
  }

  Future<void> dispose() => _states.close();

  void _emit(SyncState value) {
    if (!_states.isClosed) _states.add(value);
  }

}
