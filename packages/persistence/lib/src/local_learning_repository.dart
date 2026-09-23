import 'dart:async';

import 'package:domain/domain.dart';
import 'package:learning_engine/learning_engine.dart';
import 'package:srs/srs.dart';

import 'daos/events_dao.dart';
import 'daos/projections_dao.dart';
import 'database.dart';
import 'export_import.dart';

class LocalLearningRepository {
  final LocalDatabase database;
  final Scheduler scheduler;
  final String userId;
  final String deviceId;
  final EventsDao events;
  final ProjectionsDao projections;
  final StreamController<DashboardSnapshot> _dashboard =
      StreamController<DashboardSnapshot>.broadcast();
  LocalLearningRepository({
    required this.database,
    this.scheduler = const FsrsScheduler(),
    this.userId = 'local-user',
    this.deviceId = 'local-device',
  })  : events = EventsDao(database),
        projections = ProjectionsDao(database);

  static Future<LocalLearningRepository> inMemory({
    String userId = 'local-user',
    String deviceId = 'local-device',
  }) async {
    final database = LocalDatabase.inMemory();
    await database.open();
    return LocalLearningRepository(
      database: database,
      userId: userId,
      deviceId: deviceId,
    );
  }

  Future<LearningEvent> appendEvent(LearningEvent event) async {
    LearningEvent result = event;
    await database.transaction((tx) async {
      final txEvents = EventsDao(tx);
      final existing = await txEvents.find(event.eventId);
      if (existing != null) {
        result = existing;
        return;
      }
      await _appendEventInTransaction(tx, event);
    });
    await _publishDashboard();
    return result;
  }

  Future<void> recordReview(ReviewAttempt attempt) async {
    final now = attempt.occurredAt.toUtc();
    await database.transaction((tx) async {
      final event = LearningEvent(
        eventId: await tx.allocateEventId(deviceId),
        userId: userId,
        deviceId: deviceId,
        itemId: attempt.itemId,
        skill: attempt.skill,
        occurredAt: now,
        correct: attempt.correct,
        latencyMs: attempt.latencyMs,
        hintCount: 0,
        retryCount: 0,
        response: attempt.response,
      );
      await _appendEventInTransaction(tx, event);
    });
    await _publishDashboard();
  }

  Future<List<LearningEvent>> pendingEvents({int limit = 100}) =>
      events.pending(limit: limit);

  Future<void> markUploaded(Iterable<EventId> ids, DateTime uploadedAt) async {
    await database.transaction(
      (tx) => EventsDao(tx).markUploaded(ids, uploadedAt),
    );
  }

  /// Applies a downloaded batch, acknowledged outbox IDs, and optional cursor
  /// as one transaction so a replay or storage failure cannot split them.
  Future<void> commitSyncBatch({
    required Iterable<LearningEvent> downloadedEvents,
    required Iterable<EventId> acknowledgedIds,
    required DateTime uploadedAt,
    String? cursor,
  }) async {
    await database.transaction((tx) async {
      final txEvents = EventsDao(tx);
      for (final event in downloadedEvents) {
        await txEvents.insert(event);
      }
      await _rebuildProjections(tx, txEvents, ProjectionsDao(tx));
      await txEvents.markUploaded(acknowledgedIds, uploadedAt);
      if (cursor != null) {
        await tx.execute(
          '''INSERT INTO sync_cursor (key, value) VALUES (?, ?)
             ON CONFLICT(key) DO UPDATE SET value = excluded.value''',
          ['events', cursor],
        );
      }
    });
    await _publishDashboard();
  }

  Future<LearningSnapshot> replayLocal() async {
    await database.transaction(
      (tx) => _rebuildProjections(tx, EventsDao(tx), ProjectionsDao(tx)),
    );
    await _publishDashboard();
    return projections.snapshot();
  }

  Future<String> exportLearningData() async {
    final allEvents = await events.all();
    return LearningDataEnvelope(
      schemaVersion: currentSchemaVersion,
      contentVersion: currentContentVersion,
      algorithmVersion: algorithmVersion,
      device: {'deviceId': deviceId},
      events: allEvents,
    ).encode();
  }

  Future<void> importLearningData(String json) async {
    final envelope = LearningDataEnvelope.decode(json);
    await database.transaction((tx) async {
      final txEvents = EventsDao(tx);
      for (final event in envelope.events) {
        await txEvents.insert(event);
      }
      await _rebuildProjections(tx, txEvents, ProjectionsDao(tx));
    });
    await _publishDashboard();
  }

  /// Removes learning data while preserving the local database and identity.
  Future<void> clearLocalData() async {
    await database.transaction((tx) async {
      for (final table in const [
        'outbox_metadata',
        'learning_events',
        'review_projections',
        'confusion_edges',
        'settings',
        'sync_cursor',
      ]) {
        await tx.execute('DELETE FROM $table');
      }
    });
    await _publishDashboard();
  }

  Future<LearningSnapshot> snapshot() => projections.snapshot();

  Stream<DashboardSnapshot> watchDashboard() async* {
    yield await _dashboardSnapshot();
    yield* _dashboard.stream;
  }

  Future<void> close() async {
    await _dashboard.close();
    await database.close();
  }

  Future<void> _appendEventInTransaction(
    LocalDatabase tx,
    LearningEvent event,
  ) async {
    final txEvents = EventsDao(tx);
    await txEvents.insert(event);
    await _rebuildProjections(tx, txEvents, ProjectionsDao(tx));
  }

  Future<void> _rebuildProjections(
    LocalDatabase tx,
    EventsDao txEvents,
    ProjectionsDao txProjections,
  ) async {
    await txProjections.clear();
    final states = <String, ReviewState>{};
    for (final event in await txEvents.all()) {
      final key = '${event.itemId}|${event.skill.name}';
      final state = states[key] ?? ReviewState(
            itemId: event.itemId,
            skill: event.skill,
            difficulty: 5,
            stability: 1,
            dueAt: event.occurredAt,
            reps: 0,
          );
      final next = scheduler.schedule(
        state,
        event.correct ? ReviewRating.good : ReviewRating.again,
        event.occurredAt,
      );
      states[key] = next;
      await txProjections.saveReview(next);
      if (event.response != null && event.response!.trim().isNotEmpty) {
        await txProjections.saveConfusion(
          expected: event.itemId,
          response: event.response!,
          error: !event.correct,
        );
      }
    }
  }

  Future<DashboardSnapshot> _dashboardSnapshot() async {
    final snapshot = await projections.snapshot();
    final now = DateTime.now().toUtc();
    return DashboardSnapshot(
      dueCount: snapshot.reviewStates.where((state) => !state.dueAt.isAfter(now)).length,
      masteredCount: snapshot.reviewStates.where((state) => state.stability >= 21).length,
    );
  }

  Future<void> _publishDashboard() async {
    if (!_dashboard.isClosed) _dashboard.add(await _dashboardSnapshot());
  }
}
