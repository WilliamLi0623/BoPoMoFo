import 'package:test/test.dart';

import 'package:learning_engine/learning_engine.dart';
import 'package:domain/domain.dart';

void main() {
  test('confusion targets require exposure and rank deterministically', () {
    final engine = InMemoryConfusionEngine();
    engine.record(const ConfusionAttempt(expected: 'ㄓ', response: 'ㄔ'));
    engine.record(const ConfusionAttempt(expected: 'ㄓ', response: 'ㄔ'));
    engine.exposeCorrect('ㄅ', 'ㄆ');
    engine.exposeCorrect('ㄅ', 'ㄆ');
    engine.record(const ConfusionAttempt(expected: 'ㄅ', response: 'ㄆ'));

    expect(engine.targets().map((target) => target.key), ['ㄓ->ㄔ', 'ㄅ->ㄆ']);
  });

  test('quiz selection prefers due, then confusion, then newly unlocked items', () {
    final now = DateTime.utc(2026, 9, 22, 12);
    final snapshot = LearningSnapshot(
      reviewStates: [
        ReviewState(itemId: 'new', skill: Skill.recognition, difficulty: 5,
          stability: 1, dueAt: now.add(const Duration(days: 1)), reps: 0),
        ReviewState(itemId: 'due', skill: Skill.recognition, difficulty: 5,
          stability: 1, dueAt: now.subtract(const Duration(minutes: 1)), reps: 1),
      ],
      confusionTargets: [
        const ConfusionTarget(expected: 'confuse', response: 'wrong', errorRate: 0.5,
          exposureCount: 2, errorCount: 1),
      ],
      unlockedItems: [
        const LearningItem(itemId: 'unlocked', answer: 'ㄅ', prompt: 'b', skill: Skill.recognition),
      ],
    );

    final prompts = nextPrompts(snapshot, now, 3);

    expect(prompts.map((prompt) => prompt.itemId), ['due', 'confuse', 'unlocked']);
    expect(prompts.every((prompt) => prompt.evaluate(prompt.expectedAnswer)), isTrue);
  });

  test('due reviews preserve skill and map to all five quiz types', () {
    final now = DateTime.utc(2026, 9, 22, 12);
    final skills = [
      Skill.recognition,
      Skill.production,
      Skill.listening,
      Skill.composition,
      Skill.keyboard,
    ];
    final prompts = nextPrompts(
      LearningSnapshot(
        reviewStates: [
          for (var i = 0; i < skills.length; i++)
            ReviewState(
              itemId: 'item-$i', skill: skills[i], difficulty: 5,
              stability: 1, dueAt: now, reps: 1,
            ),
        ],
      ),
      now,
      5,
    );

    expect(prompts.map((prompt) => prompt.skill), skills);
    expect(prompts.map((prompt) => prompt.type), [
      QuizType.recognition,
      QuizType.recall,
      QuizType.listening,
      QuizType.composition,
      QuizType.keyboard,
    ]);
    expect(prompts[2].metadata['audioRequired'], isTrue);
  });

  test('prompt deduplication uses item and skill', () {
    final now = DateTime.utc(2026, 9, 22, 12);
    final prompts = nextPrompts(
      LearningSnapshot(
        reviewStates: [
          ReviewState(itemId: 'ㄓ', skill: Skill.recognition, difficulty: 5,
            stability: 1, dueAt: now, reps: 1),
          ReviewState(itemId: 'ㄓ', skill: Skill.keyboard, difficulty: 5,
            stability: 1, dueAt: now, reps: 1),
        ],
      ),
      now,
      2,
    );

    expect(prompts.map((prompt) => '${prompt.itemId}:${prompt.skill.name}'),
        ['ㄓ:recognition', 'ㄓ:keyboard']);
  });

  test('quiz selection sorts confusion targets independently', () {
    final prompts = nextPrompts(
      const LearningSnapshot(confusionTargets: [
        ConfusionTarget(expected: 'low', response: 'x', errorRate: 0.2,
          exposureCount: 5, errorCount: 1),
        ConfusionTarget(expected: 'high', response: 'y', errorRate: 0.8,
          exposureCount: 5, errorCount: 4),
      ]),
      DateTime.utc(2026),
      2,
    );

    expect(prompts.map((prompt) => prompt.itemId), ['high', 'low']);
  });
}
