import 'package:domain/domain.dart';
import 'package:learning_engine/learning_engine.dart';
import 'package:test/test.dart';

Skill skillFor(QuizType type) => switch (type) {
      QuizType.recognition => Skill.recognition,
      QuizType.recall => Skill.production,
      QuizType.composition => Skill.composition,
      QuizType.listening => Skill.listening,
      QuizType.keyboard => Skill.keyboard,
    };

QuizPrompt candidate(String id, QuizType type, String answer,
        {String? audioId}) =>
    QuizPrompt(
      id: id,
      itemId: id,
      skill: skillFor(type),
      type: type,
      promptKey: 'quiz.${type.name}',
      promptArguments: const {},
      expectedAnswer: answer,
      options: type == QuizType.composition
          ? [...answer.runes.map(String.fromCharCode).toSet(), '\u3106']
          : [answer, 'other-$id'],
      audioAssetId: audioId,
    );

void main() {
  test('confusion targets require exposure and rank deterministically', () {
    final engine = InMemoryConfusionEngine();
    engine
        .record(const ConfusionAttempt(expected: '\u3113', response: '\u3114'));
    engine
        .record(const ConfusionAttempt(expected: '\u3113', response: '\u3114'));
    engine.exposeCorrect('\u3105', '\u3106');
    engine.exposeCorrect('\u3105', '\u3106');
    engine
        .record(const ConfusionAttempt(expected: '\u3105', response: '\u3106'));

    expect(engine.targets().map((target) => target.key),
        ['\u3113->\u3114', '\u3105->\u3106']);
  });

  test('reserves two eligible prompts per type without tuple duplicates', () {
    final candidates = [
      for (final type in QuizType.values)
        for (var index = 0; index < 2; index++)
          candidate(
            '${type.name}-$index',
            type,
            index == 0 ? '\u3105\u311a' : '\u3107\u311a',
            audioId: type == QuizType.listening
                ? (index == 0 ? 'cns11643-female-ba' : 'cns11643-female-ma')
                : null,
          ),
      candidate(
          'recognition-0-duplicate', QuizType.recognition, '\u3105\u311a'),
    ];
    // A different queue ID with the same item/skill/type is still one question.
    candidates.last = QuizPrompt(
      id: 'recognition-0-duplicate',
      itemId: 'recognition-0',
      skill: Skill.recognition,
      type: QuizType.recognition,
      promptKey: 'quiz.recognition',
      promptArguments: const {},
      expectedAnswer: '\u3105\u311a',
      options: const ['\u3105\u311a', '\u3107\u311a'],
    );
    final queue = nextPrompts(
        const LearningSnapshot(), DateTime.utc(2026, 9, 30), 11,
        starterPrompts: candidates);

    expect(queue, hasLength(10));
    for (final type in QuizType.values) {
      expect(queue.where((prompt) => prompt.type == type), hasLength(2));
    }
    expect(queue.map((p) => '${p.itemId}|${p.skill}|${p.type}').toSet(),
        hasLength(queue.length));
  });

  test('after reservations fills due, confusion, then new without padding', () {
    final now = DateTime.utc(2026, 9, 30);
    final prompts = <QuizPrompt>[
      for (final type
          in QuizType.values.where((t) => t != QuizType.recognition))
        for (var index = 0; index < 2; index++)
          candidate(
              '${type.name}-$index',
              type,
              type == QuizType.listening || type == QuizType.composition
                  ? (index == 0 ? '\u3105\u311a' : '\u3107\u311a')
                  : 'answer-${type.name}-$index',
              audioId: type == QuizType.listening
                  ? (index == 0 ? 'cns11643-female-ba' : 'cns11643-female-ma')
                  : null),
      candidate('due-1', QuizType.recognition, 'due-answer-1'),
      candidate('due-2', QuizType.recognition, 'due-answer-2'),
      candidate('due-3', QuizType.recognition, 'due-answer-3'),
      candidate('confusion', QuizType.recognition, 'confusion-answer'),
      candidate('new', QuizType.recognition, 'new-answer'),
    ];
    final snapshot = LearningSnapshot(
      reviewStates: [
        for (var index = 1; index <= 3; index++)
          ReviewState(
              itemId: 'due-$index',
              skill: Skill.recognition,
              difficulty: 5,
              stability: 1,
              dueAt: now.subtract(Duration(minutes: 4 - index)),
              reps: 1),
      ],
      confusionTargets: const [
        ConfusionTarget(
            expected: 'confusion-answer',
            response: 'wrong',
            errorRate: 0.8,
            exposureCount: 5,
            errorCount: 4),
      ],
      unlockedItems: const [
        LearningItem(
            itemId: 'new',
            prompt: 'new',
            answer: 'new-answer',
            skill: Skill.recognition),
      ],
    );
    final queue = nextPrompts(snapshot, now, 13, starterPrompts: prompts);

    expect(queue, hasLength(13));
    expect(queue.take(10).where((p) => p.type == QuizType.recognition),
        hasLength(2));
    expect(queue.skip(10).map((p) => p.id), ['due-3', 'confusion', 'new']);
    expect(
        nextPrompts(snapshot, now, 20, starterPrompts: prompts), hasLength(13));
  });

  test('unmapped reviews cannot create phantom prompts', () {
    final now = DateTime.utc(2026, 9, 30);
    final queue = nextPrompts(
      LearningSnapshot(reviewStates: [
        ReviewState(
            itemId: 'missing',
            skill: Skill.listening,
            difficulty: 5,
            stability: 1,
            dueAt: now,
            reps: 1),
      ]),
      now,
      10,
    );
    expect(queue, isEmpty);
  });
}
