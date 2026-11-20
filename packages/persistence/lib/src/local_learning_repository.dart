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

  /// Binds an independent practice queue to the same learning-event store.
  QuizSessionStore quizSessions(String scope) =>
      _ScopedQuizSessions(this, '$_activeQuizSessionKey.$scope');

  static String _completionKey(String sessionKey) => '$sessionKey.completed';

  Future<Set<String>> completedQuizScopes(Iterable<String> scopes) async {
    final sessionKeys = {
      for (final scope in scopes) scope: '$_activeQuizSessionKey.$scope',
    };
    if (sessionKeys.isEmpty) return {};
    final keys = [
      for (final key in sessionKeys.values) ...[key, _completionKey(key)],
    ];
    final placeholders = List.filled(keys.length, '?').join(', ');
    final rows = await database.select(
      'SELECT key, value FROM settings WHERE key IN ($placeholders)',
      keys,
    );
    final values = {for (final row in rows) row['key']: row['value']};
    return {
      for (final entry in sessionKeys.entries)
        if (values[_completionKey(entry.value)] == '1' ||
            _isCompletedSession(values[entry.value]))
          entry.key,
    };
  }

  static bool _isCompletedSession(Object? value) {
    if (value is! String) return false;
    try {
      final json = jsonDecode(value);
      return json is Map<String, dynamic> &&
          QuizSession.fromJson(json).status == QuizSessionStatus.completed;
    } on FormatException {
      return false;
    }
  }

  Future<void> _markQuizCompleted(LocalDatabase tx, String sessionKey) =>
      tx.execute(
        'INSERT OR IGNORE INTO settings (key, value) VALUES (?, ?)',
        [_completionKey(sessionKey), '1'],
      );

  @override
  Future<QuizSession?> loadActiveSession({
    bool Function(QuizPrompt)? isPromptAvailable,
    String sessionKey = _activeQuizSessionKey,
  }) async {
    final result = await database.transaction(
      (tx) => _readActiveSession(
        tx, sessionKey, isPromptAvailable: isPromptAvailable,
      ),
    );
    // Throw outside the transaction so discarding the session is not rolled back.
    if (result.discarded) throw const QuizSessionRecoveryRequired();
    return result.session;
  }

  @override
  Future<void> saveNewSession(
    QuizSession session, {
    String sessionKey = _activeQuizSessionKey,
  }) async {
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
      final previous = (await _readActiveSession(
        tx, sessionKey, includeCompleted: true,
      )).session;
      if (previous?.status == QuizSessionStatus.active) {
        throw const QuizSessionConflict(
            'An active quiz session already exists');
      }
      if (sessionKey != _activeQuizSessionKey &&
          previous?.status == QuizSessionStatus.completed) {
        await _markQuizCompleted(tx, sessionKey);
      }
      await _writeSession(tx, sessionKey, session);
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
    String sessionKey = _activeQuizSessionKey,
  }) async {
    final updated = await database.transaction((tx) async {
      final session = (await _readActiveSession(tx, sessionKey)).session;
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
      await _writeSession(tx, sessionKey, answered);
      return answered;
    });
    await _publishDashboard();
    return updated;
  }

  @override
  Future<QuizSession> continueSession({
    required String sessionId,
    required int expectedIndex,
    String sessionKey = _activeQuizSessionKey,
  }) =>
      database.transaction((tx) async {
        final session = (await _readActiveSession(tx, sessionKey)).session;
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
        await _writeSession(tx, sessionKey, next);
        if (isLast && sessionKey != _activeQuizSessionKey) {
          await _markQuizCompleted(tx, sessionKey);
        }
        return next;
      });

  Future<({QuizSession? session, bool discarded})> _readActiveSession(
    LocalDatabase tx, String sessionKey, {
    bool Function(QuizPrompt)? isPromptAvailable,
    bool includeCompleted = false,
  }) async {
    final rows = await tx.select(
      'SELECT value FROM settings WHERE key = ?',
      [sessionKey],
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
        [sessionKey],
      );
      return (session: null, discarded: true);
    } on TypeError {
      await tx.execute(
        'DELETE FROM settings WHERE key = ?',
        [sessionKey],
      );
      return (session: null, discarded: true);
    }
    if (!includeCompleted && session.status != QuizSessionStatus.active) {
      return (session: null, discarded: false);
    }
    // The app owns bundled-content knowledge; persistence owns atomic discard.
    if (isPromptAvailable != null &&
        !session.prompts.every(isPromptAvailable)) {
      await tx.execute(
        'DELETE FROM settings WHERE key = ?',
        [sessionKey],
      );
      return (session: null, discarded: true);
    }
    return (session: session, discarded: false);
  }

  Future<void> _writeSession(
    LocalDatabase tx, String sessionKey, QuizSession session,
  ) =>
      tx.execute(
        '''INSERT INTO settings (key, value) VALUES (?, ?)
           ON CONFLICT(key) DO UPDATE SET value = excluded.value''',
        [sessionKey, jsonEncode(session.toJson())],
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

class _ScopedQuizSessions implements QuizSessionStore {
  const _ScopedQuizSessions(this._repository, this._key);

  final LocalLearningRepository _repository;
  final String _key;

  @override
  Future<QuizSession?> loadActiveSession({
    bool Function(QuizPrompt)? isPromptAvailable,
  }) =>
      _repository.loadActiveSession(
        isPromptAvailable: isPromptAvailable,
        sessionKey: _key,
      );

  @override
  Future<void> saveNewSession(QuizSession session) =>
      _repository.saveNewSession(session, sessionKey: _key);

  @override
  Future<QuizSession> submitAnswer({
    required String sessionId,
    required int expectedIndex,
    required String response,
    required bool correct,
    required DateTime occurredAt,
    required int latencyMs,
  }) =>
      _repository.submitAnswer(
        sessionId: sessionId,
        expectedIndex: expectedIndex,
        response: response,
        correct: correct,
        occurredAt: occurredAt,
        latencyMs: latencyMs,
        sessionKey: _key,
      );

  @override
  Future<QuizSession> continueSession({
    required String sessionId,
    required int expectedIndex,
  }) =>
      _repository.continueSession(
        sessionId: sessionId,
        expectedIndex: expectedIndex,
        sessionKey: _key,
      );
}
