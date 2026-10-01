import 'dart:io';
import 'dart:convert';

import 'package:test/test.dart';

import 'package:domain/domain.dart';
import 'package:srs/srs.dart';
import 'package:persistence/persistence.dart';
import 'package:learning_engine/learning_engine.dart';

class FailingScheduler implements Scheduler {
  @override
  ReviewState schedule(ReviewState state, ReviewRating rating, DateTime now) {
    throw StateError('injected projection failure');
  }
}

LearningEvent event(String id, {bool correct = true, String? response}) =>
    LearningEvent(
      eventId: id,
      userId: 'user-1',
      deviceId: 'device-1',
      itemId: 'ㄓ',
      skill: Skill.recognition,
      occurredAt: DateTime.utc(2026, 9, 22, 12),
      correct: correct,
      latencyMs: 100,
      hintCount: 0,
      retryCount: 0,
      response: response,
    );

QuizSession quizSession({int index = 0, bool answered = false}) => QuizSession(
      id: 'session-1',
      contentVersion: 'starter-v1',
      prompts: List.generate(
          4,
          (i) => QuizPrompt(
                id: 'prompt-$i',
                itemId: 'item-$i',
                skill: Skill.recognition,
                type: QuizType.recognition,
                promptKey: 'recognize',
                promptArguments: {'position': '$i'},
                expectedAnswer: 'answer-$i',
                options: ['wrong-$i', 'answer-$i'],
              )),
      currentIndex: index,
      currentQuestionStartedAt: DateTime.utc(2026, 9, 30, 12, index),
      currentAnswer: answered
          ? QuizAnswer(
              response: 'answer-$index',
              correct: true,
              occurredAt: DateTime.utc(2026, 9, 30, 12, index, 1),
              latencyMs: 240,
            )
          : null,
      correctCount: index + (answered ? 1 : 0),
      answeredCount: index + (answered ? 1 : 0),
      status: QuizSessionStatus.active,
    );

void main() {
  test(
      'answered session at index 3 restores its exact ordered queue and feedback after reopen',
      () async {
    final directory =
        await Directory.systemTemp.createTemp('bopomofo-session-');
    final path = '${directory.path}${Platform.pathSeparator}learning.sqlite';
    var expected = quizSession();
    final first = LocalLearningRepository(database: LocalDatabase.atPath(path));
    try {
      await first.database.open();
      await first.saveNewSession(expected);
      for (var index = 0; index < 4; index++) {
        expected = await first.submitAnswer(
          sessionId: expected.id,
          expectedIndex: index,
          response: 'answer-$index',
          correct: true,
          occurredAt: DateTime.utc(2026, 9, 30, 12, index, 1),
          latencyMs: 240,
        );
        if (index < 3) {
          expected = await first.continueSession(
            sessionId: expected.id,
            expectedIndex: index,
          );
        }
      }
      await first.close();
      final second =
          LocalLearningRepository(database: LocalDatabase.atPath(path));
      try {
        await second.database.open();
        expect((await second.loadActiveSession())?.toJson(), expected.toJson());
      } finally {
        await second.close();
      }
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test('saveNewSession rejects a session that already contains answers',
      () async {
    final repository = await LocalLearningRepository.inMemory();
    try {
      await expectLater(
        repository.saveNewSession(quizSession(answered: true)),
        throwsFormatException,
      );
      expect(await repository.loadActiveSession(), isNull);
      expect(await repository.events.all(), isEmpty);
    } finally {
      await repository.close();
    }
  });

  test(
      'answer saves one event and feedback while repeat and stale writes add none',
      () async {
    final repository = await LocalLearningRepository.inMemory();
    try {
      await repository.saveNewSession(quizSession());
      final answered = await repository.submitAnswer(
        sessionId: 'session-1',
        expectedIndex: 0,
        response: 'answer-0',
        correct: true,
        occurredAt: DateTime.utc(2026, 9, 30, 12, 0, 1),
        latencyMs: 240,
      );
      expect(answered.currentIndex, 0);
      expect(answered.currentAnswer?.response, 'answer-0');
      expect(answered.currentAnswer?.correct, isTrue);
      expect((answered.answeredCount, answered.correctCount), (1, 1));
      expect((await repository.events.all()).single.itemId, 'item-0');
      expect((await repository.snapshot()).reviewStates.single.reps, 1);
      await expectLater(
          repository.submitAnswer(
            sessionId: 'session-1',
            expectedIndex: 0,
            response: 'answer-0',
            correct: true,
            occurredAt: DateTime.utc(2026, 9, 30, 12, 0, 1),
            latencyMs: 240,
          ),
          throwsA(isA<QuizSessionConflict>()));
      await expectLater(
          repository.submitAnswer(
            sessionId: 'session-1',
            expectedIndex: 1,
            response: 'answer-1',
            correct: true,
            occurredAt: DateTime.utc(2026, 9, 30, 12, 1),
            latencyMs: 240,
          ),
          throwsA(isA<QuizSessionConflict>()));
      expect(await repository.events.all(), hasLength(1));
      expect(
          (await repository.loadActiveSession())?.toJson(), answered.toJson());
    } finally {
      await repository.close();
    }
  });

  test('projection failure rolls back answer and event together', () async {
    final database = LocalDatabase.inMemory();
    await database.open();
    final repository = LocalLearningRepository(
        database: database, scheduler: FailingScheduler());
    try {
      final original = quizSession();
      await repository.saveNewSession(original);
      await expectLater(
          repository.submitAnswer(
            sessionId: original.id,
            expectedIndex: 0,
            response: 'answer-0',
            correct: true,
            occurredAt: DateTime.utc(2026, 9, 30),
            latencyMs: 240,
          ),
          throwsStateError);
      expect(await repository.events.all(), isEmpty);
      expect(await repository.pendingEvents(), isEmpty);
      expect(
          (await repository.loadActiveSession())?.toJson(), original.toJson());
    } finally {
      await repository.close();
    }
  });

  test('Continue requires saved answer and matching ID and index', () async {
    final repository = await LocalLearningRepository.inMemory();
    try {
      await repository.saveNewSession(quizSession());
      await expectLater(
          repository.continueSession(sessionId: 'session-1', expectedIndex: 0),
          throwsA(isA<QuizSessionConflict>()));
      await repository.submitAnswer(
        sessionId: 'session-1',
        expectedIndex: 0,
        response: 'answer-0',
        correct: true,
        occurredAt: DateTime.utc(2026, 9, 30),
        latencyMs: 240,
      );
      await expectLater(
          repository.continueSession(sessionId: 'other', expectedIndex: 0),
          throwsA(isA<QuizSessionConflict>()));
      final next = await repository.continueSession(
          sessionId: 'session-1', expectedIndex: 0);
      expect(next.currentIndex, 1);
      expect(next.currentAnswer, isNull);
      expect(next.answeredCount, 1);
      await expectLater(
          repository.continueSession(sessionId: 'session-1', expectedIndex: 0),
          throwsA(isA<QuizSessionConflict>()));
      expect((await repository.loadActiveSession())?.toJson(), next.toJson());
      expect(await repository.events.all(), hasLength(1));
    } finally {
      await repository.close();
    }
  });

  test(
      'unsupported session codec or content is discarded without deleting events',
      () async {
    final repository = await LocalLearningRepository.inMemory();
    try {
      await repository.appendEvent(event('kept-1'));
      await repository.saveNewSession(quizSession());
      final rows =
          await repository.database.select('SELECT key, value FROM settings');
      expect(rows, hasLength(1));
      final key = rows.single['key'] as String;
      final original =
          jsonDecode(rows.single['value'] as String) as Map<String, dynamic>;
      for (final patch in [
        {'codecVersion': 999},
        {'contentVersion': 'future-content'},
      ]) {
        await repository.database
            .execute('UPDATE settings SET value = ? WHERE key = ?', [
          jsonEncode({...original, ...patch}),
          key
        ]);
        expect(await repository.loadActiveSession(), isNull);
        expect(await repository.events.all(), hasLength(1));
        await repository.saveNewSession(quizSession());
      }
    } finally {
      await repository.close();
    }
  });

  test('session stays out of export and clearLocalData removes it', () async {
    final repository = await LocalLearningRepository.inMemory();
    try {
      await repository.saveNewSession(quizSession());
      expect(
          await repository.exportLearningData(), isNot(contains('session-1')));
      await repository.clearLocalData();
      expect(await repository.loadActiveSession(), isNull);
    } finally {
      await repository.close();
    }
  });

  test(
      'unique event IDs are idempotent and upload acknowledgement keeps history',
      () async {
    final repository = await LocalLearningRepository.inMemory();
    await repository.appendEvent(event('e1'));
    await repository.appendEvent(event('e1', correct: false));

    expect((await repository.pendingEvents()).map((e) => e.eventId), ['e1']);
    await repository.markUploaded(['e1'], DateTime.utc(2026, 9, 23));
    expect(await repository.pendingEvents(), isEmpty);
    expect((await repository.replayLocal()).reviewStates.single.reps, 1);
    await repository.close();
  });

  test('review transaction updates projection and confusion atomically',
      () async {
    final repository = await LocalLearningRepository.inMemory();
    await repository.appendEvent(event('e1', correct: false, response: 'ㄔ'));
    await repository.appendEvent(event('e2', correct: false, response: 'ㄔ'));

    final snapshot = await repository.replayLocal();
    expect(snapshot.reviewStates.single.reps, 2);
    expect(snapshot.confusionTargets.single.key, 'ㄓ->ㄔ');
    await repository.close();
  });

  test('recorded confusion prioritizes prompt by stable item ID', () async {
    final repository = await LocalLearningRepository.inMemory();
    final prompt = QuizPrompt(
      id: 'starter-ba-recognition',
      itemId: 'starter-ba',
      skill: Skill.recognition,
      type: QuizType.recognition,
      promptKey: 'quiz.recognition',
      promptArguments: const {},
      expectedAnswer: 'ba',
      options: const ['ba', 'pa'],
    );
    var session = QuizSession(
      id: 'confusion-session',
      contentVersion: 'starter-v1',
      prompts: [
        prompt,
        QuizPrompt(
          id: 'starter-ba-recall',
          itemId: 'starter-ba',
          skill: Skill.production,
          type: QuizType.recall,
          promptKey: 'quiz.recall',
          promptArguments: const {},
          expectedAnswer: 'ba',
          options: const ['ba', 'pa'],
        ),
      ],
      currentIndex: 0,
      currentQuestionStartedAt: DateTime.utc(2026, 9, 30),
      currentAnswer: null,
      correctCount: 0,
      answeredCount: 0,
      status: QuizSessionStatus.active,
    );
    try {
      await repository.saveNewSession(session);
      for (var index = 0; index < 2; index++) {
        await repository.submitAnswer(
          sessionId: session.id,
          expectedIndex: index,
          response: 'pa',
          correct: false,
          occurredAt: DateTime.utc(2026, 9, 30, 0, index + 1),
          latencyMs: 250,
        );
        if (index == 0) {
          session = await repository.continueSession(
            sessionId: session.id,
            expectedIndex: index,
          );
        }
      }

      final persisted = await repository.snapshot();
      expect(persisted.confusionTargets.single.expected, 'starter-ba');
      expect(prompt.itemId, isNot(prompt.expectedAnswer));

      final queue = nextPrompts(
        LearningSnapshot(confusionTargets: persisted.confusionTargets),
        DateTime.utc(2026, 10, 1),
        2,
        starterPrompts: [
          QuizPrompt(
            id: 'starter-pa-recognition',
            itemId: 'starter-pa',
            skill: Skill.recognition,
            type: QuizType.recognition,
            promptKey: 'quiz.recognition',
            promptArguments: const {},
            expectedAnswer: 'pa',
            options: const ['pa', 'ba'],
          ),
          prompt,
        ],
      );

      expect(queue.first.itemId, 'starter-ba');
    } finally {
      await repository.close();
    }
  });

  test('reopening the SQLite database recovers events and projections',
      () async {
    final directory =
        await Directory.systemTemp.createTemp('bopomofo-persistence-');
    final path = '${directory.path}${Platform.pathSeparator}learning.sqlite';
    final first = LocalLearningRepository(
      database: LocalDatabase.atPath(path),
    );
    await first.database.open();
    await first.appendEvent(event('restart-1'));
    await first.close();

    final second = LocalLearningRepository(
      database: LocalDatabase.atPath(path),
    );
    await second.database.open();
    expect((await second.replayLocal()).reviewStates.single.reps, 1);
    await second.close();
    await directory.delete(recursive: true);
  });

  test('failed review rolls back event, outbox, and projections together',
      () async {
    final database = LocalDatabase.inMemory();
    await database.open();
    final repository = LocalLearningRepository(
      database: database,
      scheduler: FailingScheduler(),
    );

    await expectLater(
        repository.appendEvent(event('rollback-1')), throwsStateError);
    expect(await repository.events.all(), isEmpty);
    expect(await repository.pendingEvents(), isEmpty);
    expect((await repository.replayLocal()).reviewStates, isEmpty);
    await repository.close();
  });

  test(
      'applies the v1 to v2 additive migration instead of only bumping metadata',
      () async {
    final database = LocalDatabase.inMemory();
    await database.execute('''
      CREATE TABLE schema_info (
        singleton INTEGER PRIMARY KEY CHECK (singleton = 1),
        version INTEGER NOT NULL
      )
    ''');
    await database.execute(
      'INSERT INTO schema_info (singleton, version) VALUES (1, 1)',
    );
    await database.execute('''
      CREATE TABLE device_identity (
        singleton INTEGER PRIMARY KEY CHECK (singleton = 1),
        device_id TEXT NOT NULL,
        platform TEXT NOT NULL,
        app_version TEXT NOT NULL
      )
    ''');

    await database.open();
    final columns = await database.select('PRAGMA table_info(device_identity)');
    expect(columns.map((row) => row['name']), contains('next_event_sequence'));
    expect(
      (await database.select('SELECT version FROM schema_info'))
          .single['version'],
      2,
    );
    await database.close();
  });

  test('generated event IDs remain unique after repository restart', () async {
    final directory = await Directory.systemTemp.createTemp('bopomofo-id-');
    final path = '${directory.path}${Platform.pathSeparator}learning.sqlite';
    final occurredAt = DateTime.utc(2026, 9, 22, 12);
    final attempt = ReviewAttempt(
      itemId: 'ㄓ',
      skill: Skill.recognition,
      correct: true,
      occurredAt: occurredAt,
    );

    final first = LocalLearningRepository(database: LocalDatabase.atPath(path));
    await first.database.open();
    await first.recordReview(attempt);
    await first.close();

    final second =
        LocalLearningRepository(database: LocalDatabase.atPath(path));
    await second.database.open();
    await second.recordReview(attempt);
    final ids =
        (await second.events.all()).map((event) => event.eventId).toSet();

    expect(ids, hasLength(2));
    await second.close();
    await directory.delete(recursive: true);
  });
}
