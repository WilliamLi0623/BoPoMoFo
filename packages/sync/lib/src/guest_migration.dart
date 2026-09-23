import 'package:domain/domain.dart';
import 'package:learning_engine/learning_engine.dart' show LearningSnapshot;
import 'package:persistence/persistence.dart';

import 'sync_service.dart';
import 'sync_state.dart';

class GuestMigrationResult {
  final List<LearningEvent> events;

  const GuestMigrationResult(this.events);

  Future<LearningSnapshot> replayInto(LocalLearningRepository repository) async {
    for (final event in events) {
      await repository.appendEvent(event);
    }
    return repository.replayLocal();
  }
}

class GuestMigration {
  const GuestMigration._();

  static GuestMigrationResult merge({
    required Iterable<LearningEvent> local,
    required Iterable<LearningEvent> remote,
    required String authenticatedUserId,
  }) {
    final merged = <String, LearningEvent>{};
    for (final event in [...local, ...remote]) {
      merged.putIfAbsent(event.eventId, () => _forUser(event, authenticatedUserId));
    }
    final events = merged.values.toList()
      ..sort((a, b) {
        final time = a.occurredAt.compareTo(b.occurredAt);
        return time != 0 ? time : a.eventId.compareTo(b.eventId);
      });
    return GuestMigrationResult(List.unmodifiable(events));
  }

  static Future<GuestMigrationResult> migrate({
    required LocalLearningRepository repository,
    required SyncTransport transport,
    required String authenticatedUserId,
  }) async {
    final local = await repository.events.all();
    final remote = (await transport.download(cursor: SyncCursor.initial)).events;
    final result = merge(
      local: local,
      remote: remote,
      authenticatedUserId: authenticatedUserId,
    );
    final upload = await transport.upload(result.events);
    await repository.commitSyncBatch(
      downloadedEvents: result.events,
      acknowledgedIds: upload.acknowledgedIds,
      uploadedAt: DateTime.now().toUtc(),
    );
    return result;
  }

  static LearningEvent _forUser(LearningEvent event, String userId) => LearningEvent(
        eventId: event.eventId,
        userId: userId,
        deviceId: event.deviceId,
        itemId: event.itemId,
        skill: event.skill,
        occurredAt: event.occurredAt,
        correct: event.correct,
        latencyMs: event.latencyMs,
        hintCount: event.hintCount,
        retryCount: event.retryCount,
        response: event.response,
      );
}
