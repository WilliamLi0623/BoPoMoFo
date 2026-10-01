import 'dart:convert';

import 'package:domain/domain.dart';
import 'package:learning_engine/learning_engine.dart';
import 'package:test/test.dart';

QuizPrompt prompt(String id, {QuizType type = QuizType.recognition}) =>
    QuizPrompt(
      id: id,
      itemId: id,
      skill: type == QuizType.listening ? Skill.listening : Skill.recognition,
      type: type,
      promptKey: 'quiz.recognition',
      promptArguments: const {'glyph': '\u3105'},
      expectedAnswer: type == QuizType.listening ? '\u3105\u311a' : 'b',
      options: type == QuizType.listening
          ? const ['\u3107\u311a', '\u3105\u311a']
          : const ['p', 'b'],
      audioAssetId: type == QuizType.listening ? 'cns11643-female-ba' : null,
    );

QuizSession session({List<QuizPrompt>? prompts}) => QuizSession(
      id: 'session-1',
      contentVersion: 'starter-v1',
      prompts: prompts ??
          [prompt('first'), prompt('second', type: QuizType.listening)],
      currentIndex: 0,
      currentQuestionStartedAt: DateTime.utc(2026, 9, 30, 12),
      currentAnswer: null,
      correctCount: 0,
      answeredCount: 0,
      status: QuizSessionStatus.active,
    );

class MemoryStore implements QuizSessionStore {
  QuizSession? value;
  int submitted = 0;

  @override
  Future<QuizSession?> loadActiveSession({
    bool Function(QuizPrompt)? isPromptAvailable,
  }) async {
    final session = value?.status == QuizSessionStatus.active ? value : null;
    if (session != null &&
        isPromptAvailable != null &&
        !session.prompts.every(isPromptAvailable)) {
      value = null;
      throw const QuizSessionRecoveryRequired();
    }
    return session;
  }

  @override
  Future<void> saveNewSession(QuizSession session) async {
    value = session;
  }

  void check(String id, int index) {
    if (value == null ||
        value!.id != id ||
        value!.currentIndex != index ||
        value!.status != QuizSessionStatus.active) {
      throw QuizSessionConflict('stale session');
    }
  }

  @override
  Future<QuizSession> submitAnswer(
      {required String sessionId,
      required int expectedIndex,
      required String response,
      required bool correct,
      required DateTime occurredAt,
      required int latencyMs}) async {
    check(sessionId, expectedIndex);
    if (value!.currentAnswer != null)
      throw QuizSessionConflict('already answered');
    submitted++;
    value = value!.copyWith(
      currentAnswer: QuizAnswer(
          response: response,
          correct: correct,
          occurredAt: occurredAt,
          latencyMs: latencyMs),
      correctCount: value!.correctCount + (correct ? 1 : 0),
      answeredCount: value!.answeredCount + 1,
    );
    return value!;
  }

  @override
  Future<QuizSession> continueSession(
      {required String sessionId, required int expectedIndex}) async {
    check(sessionId, expectedIndex);
    if (value!.currentAnswer == null) throw QuizSessionConflict('not answered');
    final nextIndex = expectedIndex + 1;
    value = value!.copyWith(
      currentIndex: nextIndex,
      clearAnswer: true,
      currentQuestionStartedAt: DateTime.utc(2026, 9, 30, 12, 1),
      status: nextIndex == value!.prompts.length
          ? QuizSessionStatus.completed
          : QuizSessionStatus.active,
    );
    return value!;
  }
}

void main() {
  test('session JSON round trip preserves queue order, options, and audio IDs',
      () {
    final original = session();
    final restored = QuizSession.fromJson(
        jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>);

    expect(restored.id, original.id);
    expect(restored.contentVersion, original.contentVersion);
    expect(restored.prompts.map((p) => p.id), ['first', 'second']);
    expect(restored.prompts.map((p) => p.options), [
      ['p', 'b'],
      ['\u3107\u311a', '\u3105\u311a']
    ]);
    expect(restored.prompts.last.audioAssetId, 'cns11643-female-ba');
    expect(restored.prompts.first.evaluate(' b '), isTrue);
    expect(() => restored.prompts.clear(), throwsUnsupportedError);
  });

  test('codec rejects unsupported version and invalid session index', () {
    final valid = session().toJson();
    expect(() => QuizSession.fromJson({...valid, 'codecVersion': 999}),
        throwsFormatException);
    expect(() => QuizSession.fromJson({...valid, 'currentIndex': 2}),
        throwsFormatException);
  });

  test('codec rejects duplicate queue IDs and malformed options', () {
    final valid = session().toJson();
    final duplicate = [prompt('same').toJson(), prompt('same').toJson()];
    expect(() => QuizSession.fromJson({...valid, 'prompts': duplicate}),
        throwsFormatException);
    final malformed = prompt('first').toJson();
    malformed['options'] = ['b', 'b'];
    expect(() => QuizPrompt.fromJson(malformed), throwsFormatException);
    malformed['options'] = ['p'];
    expect(() => QuizPrompt.fromJson(malformed), throwsFormatException);
    final missingTile = {
      ...malformed,
      'type': QuizType.composition.name,
      'expectedAnswer': '\u3105\u311a',
      'options': ['\u3105', '\u3107'],
    };
    expect(() => QuizPrompt.fromJson(missingTile), throwsFormatException);
  });

  test('coordinator resumes and records correct answer exactly once', () async {
    final store = MemoryStore();
    var clockSeconds = 0;
    final coordinator = QuizSessionCoordinator(
      store: store,
      queueFactory: () async => [prompt('first'), prompt('second')],
      newSessionId: () => 'session-1',
      now: () =>
          DateTime.utc(2026, 9, 30, 12).add(Duration(seconds: clockSeconds++)),
      contentVersion: 'starter-v1',
    );
    final started = await coordinator.loadOrStartSession();
    expect(started!.prompts, hasLength(2));
    expect((await coordinator.loadOrStartSession())!.id, started.id);
    final answered = await coordinator.submitAnswer(' b ');
    expect(answered.currentAnswer!.correct, isTrue);
    expect(answered.currentAnswer!.response, ' b ');
    expect(answered.currentAnswer!.latencyMs, 1000);
    expect(answered.correctCount, 1);
    expect(answered.answeredCount, 1);
    expect(store.submitted, 1);
    await expectLater(
        coordinator.submitAnswer('b'), throwsA(isA<QuizSessionConflict>()));
    expect(store.submitted, 1);
    expect((await coordinator.continueSession()).currentIndex, 1);
    await expectLater(
        coordinator.continueSession(), throwsA(isA<QuizSessionConflict>()));
  });

  test('incorrect answer waits for Continue, then final Continue completes',
      () async {
    final store = MemoryStore();
    final coordinator = QuizSessionCoordinator(
      store: store,
      queueFactory: () async => [prompt('only')],
      newSessionId: () => 'session-1',
      now: () => DateTime.utc(2026, 9, 30, 12, 0, 1),
      contentVersion: 'starter-v1',
    );
    await coordinator.loadOrStartSession();
    final answered = await coordinator.submitAnswer('wrong');
    expect(answered.currentIndex, 0);
    expect(answered.currentAnswer!.correct, isFalse);
    expect(answered.correctCount, 0);
    expect(answered.answeredCount, 1);
    final completed = await coordinator.continueSession();
    expect(completed.status, QuizSessionStatus.completed);
    expect(completed.currentIndex, 1);
    expect(await store.loadActiveSession(), isNull);
  });

  test('stale coordinator cannot answer a later question', () async {
    final store = MemoryStore();
    QuizSessionCoordinator coordinator() => QuizSessionCoordinator(
          store: store,
          queueFactory: () async => [prompt('first'), prompt('second')],
          newSessionId: () => 'session-1',
          now: () => DateTime.utc(2026, 9, 30, 12, 0, 1),
          contentVersion: 'starter-v1',
        );
    final a = coordinator();
    final b = coordinator();
    await a.loadOrStartSession();
    await b.loadOrStartSession();

    await a.submitAnswer('b');
    await a.continueSession();
    await expectLater(b.submitAnswer('b'), throwsA(isA<QuizSessionConflict>()));

    expect(store.submitted, 1);
    expect(store.value!.currentIndex, 1);
    expect(store.value!.currentAnswer, isNull);
    expect(store.value!.answeredCount, 1);
  });

  test('stale Continue cannot advance another question with saved feedback',
      () async {
    final store = MemoryStore();
    QuizSessionCoordinator coordinator() => QuizSessionCoordinator(
          store: store,
          queueFactory: () async =>
              [prompt('first'), prompt('second'), prompt('third')],
          newSessionId: () => 'session-1',
          now: () => DateTime.utc(2026, 9, 30, 12, 0, 1),
          contentVersion: 'starter-v1',
        );
    final a = coordinator();
    final b = coordinator();
    await a.loadOrStartSession();
    await a.submitAnswer('b');
    await b.loadOrStartSession(); // B observed feedback for question zero.
    await a.continueSession();
    await a.submitAnswer('wrong');

    await expectLater(b.continueSession(), throwsA(isA<QuizSessionConflict>()));

    expect(store.value!.currentIndex, 1);
    expect(store.value!.currentAnswer!.response, 'wrong');
    expect(store.value!.answeredCount, 2);
    expect(store.submitted, 2);
  });

  test('empty queue yields no active session', () async {
    final store = MemoryStore();
    final coordinator = QuizSessionCoordinator(
      store: store,
      queueFactory: () async => [],
      newSessionId: () => 'unused',
      now: () => DateTime.utc(2026),
      contentVersion: 'starter-v1',
    );
    expect(await coordinator.loadOrStartSession(), isNull);
    expect(store.value, isNull);
  });
}
