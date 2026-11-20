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
    SyncTransport? transport,
    Future<SyncTransport?> Function()? resolveTransport,
    this.cursorKey = 'events',
    DateTime Function()? clock,
  })  : assert(transport == null || resolveTransport == null),
        _resolveTransport = resolveTransport ?? (() async => transport),
        _clock = clock ?? (() => DateTime.now().toUtc());

  final LocalLearningRepository repository;
  final String cursorKey;
  final Future<SyncTransport?> Function() _resolveTransport;
  final DateTime Function() _clock;
  final StreamController<SyncState> _states =
      StreamController<SyncState>.broadcast();
  DateTime? _lastSuccessfulSync;
  Future<SyncResult>? _activeSync;

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
  Future<SyncResult> syncNow() =>
      _activeSync ??= _sync().whenComplete(() => _activeSync = null);

  Future<SyncResult> _sync() async {
    try {
      final transport = await _resolveTransport();
      final pending = await repository.pendingEvents();
      if (transport == null) {
        _emit(SyncState(
            status: SyncStatus.localOnly, pendingCount: pending.length));
        return const SyncResult(status: SyncStatus.localOnly);
      }
      if (pending.isNotEmpty) {
        _emit(SyncState(
          status: SyncStatus.pending,
          pendingCount: pending.length,
          lastSuccessfulSync: _lastSuccessfulSync,
          retry: syncNow,
        ));
      }
      final upload = pending.isEmpty
          ? UploadResult(acknowledgedIds: const [])
          : await transport.upload(List<LearningEvent>.unmodifiable(pending));
      final cursor = await readCursor();
      final download = await transport.download(cursor: cursor);
      await repository.commitSyncBatch(
        downloadedEvents: download.events,
        acknowledgedIds: {
          ...upload.acknowledgedIds,
          ...download.events.map((event) => event.eventId),
        },
        uploadedAt: _clock(),
        cursor: download.nextCursor.value,
        cursorKey: cursorKey,
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
    } on SyncAccountMismatch {
      return _failure(SyncStatus.accountMismatch);
    } catch (_) {
      return _failure(SyncStatus.error);
    }
  }

  Future<SyncResult> _failure(SyncStatus status) async {
    final remaining = await repository.pendingEvents();
    const message = 'Sync failed. Progress remains saved locally.';
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
  Future<void> scheduleBackgroundSync() async => syncNow();

  Future<SyncCursor> readCursor() async {
    final rows = await repository.database.select(
      'SELECT value FROM sync_cursor WHERE key = ?',
      [cursorKey],
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
