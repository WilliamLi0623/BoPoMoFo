import 'dart:async';
import 'dart:convert';

import 'package:domain/domain.dart';
import 'package:learning_engine/learning_engine.dart';
import 'package:srs/srs.dart';

import 'daos/events_dao.dart';
import 'daos/projections_dao.dart';
import 'database.dart';
import 'export_import.dart';

class LocalLearningRepository implements QuizSessionStore {
  static const _activeQuizSessionKey = 'quiz.activeSession';
  static const _supportedQuizContentVersion = 'starter-v1';
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

  @override
  Future<QuizSession?> loadActiveSession({
    bool Function(QuizPrompt)? isPromptAvailable,
  }) async {
    final result = await database.transaction(
      (tx) => _readActiveSession(tx, isPromptAvailable: isPromptAvailable),
    );
    // Throw outside the transaction so discarding the session is not rolled back.
    if (result.discarded) throw const QuizSessionRecoveryRequired();
    return result.session;
  }

  @override
  Future<void> saveNewSession(QuizSession session) async {
    if (session.status != QuizSessionStatus.active ||
        session.contentVersion != _supportedQuizContentVersion) {
      throw const FormatException('Unsupported or inactive quiz session');
    }
    if (session.currentIndex != 0 ||
        session.currentAnswer != null ||
        session.answeredCount != 0 ||
        session.correctCount != 0) {
      throw const FormatException('A new quiz session must be unanswered');
    }
    await database.transaction((tx) async {
      if ((await _readActiveSession(tx)).session != null) {
        throw const QuizSessionConflict(
            'An active quiz session already exists');
      }
      await _writeSession(tx, session);
    });
  }

  @override
  Future<QuizSession> submitAnswer({
    required String sessionId,
    required int expectedIndex,
    required String response,
    required bool correct,
    required DateTime occurredAt,
    required int latencyMs,
  }) async {
    final updated = await database.transaction((tx) async {
      final session = (await _readActiveSession(tx)).session;
      if (session == null ||
          session.id != sessionId ||
          session.currentIndex != expectedIndex ||
          session.currentAnswer != null) {
        throw const QuizSessionConflict('Stale quiz answer');
      }
      if (latencyMs < 0 ||
          correct != session.currentPrompt!.evaluate(response)) {
        throw ArgumentError('Invalid quiz answer');
      }
      final prompt = session.currentPrompt!;
      final answer = QuizAnswer(
        response: response,
        correct: correct,
        occurredAt: occurredAt.toUtc(),
        latencyMs: latencyMs,
      );
      final event = LearningEvent(
        eventId: await tx.allocateEventId(deviceId),
        userId: userId,
        deviceId: deviceId,
        itemId: prompt.itemId,
        skill: prompt.skill,
        occurredAt: answer.occurredAt,
        correct: correct,
        latencyMs: latencyMs,
        hintCount: 0,
        retryCount: 0,
        response: response,
      );
      await _appendEventInTransaction(tx, event);
      final answered = session.copyWith(
        currentAnswer: answer,
        correctCount: session.correctCount + (correct ? 1 : 0),
        answeredCount: session.answeredCount + 1,
      );
      await _writeSession(tx, answered);
      return answered;
    });
    await _publishDashboard();
    return updated;
  }

  @override
  Future<QuizSession> continueSession({
    required String sessionId,
    required int expectedIndex,
  }) =>
      database.transaction((tx) async {
        final session = (await _readActiveSession(tx)).session;
        if (session == null ||
            session.id != sessionId ||
            session.currentIndex != expectedIndex ||
            session.currentAnswer == null) {
          throw const QuizSessionConflict('Stale quiz continuation');
        }
        final isLast = expectedIndex == session.prompts.length - 1;
        final next = session.copyWith(
          currentIndex: expectedIndex + 1,
          currentQuestionStartedAt: DateTime.now().toUtc(),
          clearAnswer: true,
          status:
              isLast ? QuizSessionStatus.completed : QuizSessionStatus.active,
        );
        await _writeSession(tx, next);
        return next;
      });

  Future<({QuizSession? session, bool discarded})> _readActiveSession(
    LocalDatabase tx, {
    bool Function(QuizPrompt)? isPromptAvailable,
  }) async {
    final rows = await tx.select(
      'SELECT value FROM settings WHERE key = ?',
      [_activeQuizSessionKey],
    );
    if (rows.isEmpty) return (session: null, discarded: false);
    QuizSession session;
    try {
      final decoded = jsonDecode(rows.single['value']! as String);
      session = QuizSession.fromJson(decoded as Map<String, dynamic>);
      if (session.contentVersion != _supportedQuizContentVersion) {
        throw const FormatException('Unsupported quiz content version');
      }
    } on FormatException {
      await tx.execute(
        'DELETE FROM settings WHERE key = ?',
        [_activeQuizSessionKey],
      );
      return (session: null, discarded: true);
    } on TypeError {
      await tx.execute(
        'DELETE FROM settings WHERE key = ?',
        [_activeQuizSessionKey],
      );
      return (session: null, discarded: true);
    }
    if (session.status != QuizSessionStatus.active) {
      return (session: null, discarded: false);
    }
    // The app owns bundled-content knowledge; persistence owns atomic discard.
    if (isPromptAvailable != null &&
        !session.prompts.every(isPromptAvailable)) {
      await tx.execute(
        'DELETE FROM settings WHERE key = ?',
        [_activeQuizSessionKey],
      );
      return (session: null, discarded: true);
    }
    return (session: session, discarded: false);
  }

  Future<void> _writeSession(LocalDatabase tx, QuizSession session) =>
      tx.execute(
        '''INSERT INTO settings (key, value) VALUES (?, ?)
           ON CONFLICT(key) DO UPDATE SET value = excluded.value''',
        [_activeQuizSessionKey, jsonEncode(session.toJson())],
      );

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
    String cursorKey = 'events',
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
          [cursorKey, cursor],
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
      final state = states[key] ??
          ReviewState(
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
      dueCount: snapshot.reviewStates
          .where((state) => !state.dueAt.isAfter(now))
          .length,
      masteredCount:
          snapshot.reviewStates.where((state) => state.stability >= 21).length,
    );
  }

  Future<void> _publishDashboard() async {
    if (!_dashboard.isClosed) _dashboard.add(await _dashboardSnapshot());
  }
}
