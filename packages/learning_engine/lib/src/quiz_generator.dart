import 'package:domain/domain.dart';
import 'confusion_engine.dart';

typedef AnswerEvaluator = bool Function(String answer);

enum QuizType { recognition, recall, composition, listening, keyboard }

class LearningItem {
  final String itemId;
  final String prompt;
  final String answer;
  final Skill skill;

  const LearningItem({required this.itemId, required this.prompt, required this.answer, required this.skill});
}

class QuizPrompt {
  final String itemId;
  final Skill skill;
  final QuizType type;
  final String prompt;
  final String expectedAnswer;
  final AnswerEvaluator evaluate;
  final Map<String, Object?> metadata;

  const QuizPrompt({required this.itemId, required this.skill, required this.type, required this.prompt, required this.expectedAnswer, required this.evaluate, this.metadata = const {}});
}

class LearningSnapshot {
  final List<ReviewState> reviewStates;
  final List<ConfusionTarget> confusionTargets;
  final List<LearningItem> unlockedItems;

  const LearningSnapshot({this.reviewStates = const [], this.confusionTargets = const [], this.unlockedItems = const []});
}

List<QuizPrompt> nextPrompts(LearningSnapshot snapshot, DateTime now, int limit) {
  if (limit <= 0) return const [];
  final result = <QuizPrompt>[];
  final used = <String>{};
  void add(QuizPrompt prompt) {
    final key = '${prompt.itemId}|${prompt.skill.name}';
    if (result.length < limit && used.add(key)) result.add(prompt);
  }

  final due = snapshot.reviewStates.where((state) => !state.dueAt.isAfter(now)).toList()
    ..sort((a, b) => a.dueAt.compareTo(b.dueAt));
  for (final state in due) {
    add(_prompt(state.itemId, state.skill, state.itemId, state.itemId, _typeFor(state.skill)));
  }
  final confusionTargets = [...snapshot.confusionTargets]
    ..sort((a, b) => b.errorRate.compareTo(a.errorRate) != 0
        ? b.errorRate.compareTo(a.errorRate)
        : a.key.compareTo(b.key));
  for (final target in confusionTargets) {
    add(_prompt(target.expected, Skill.recognition, target.response, target.expected, QuizType.recognition));
  }
  for (final item in snapshot.unlockedItems) {
    add(_prompt(item.itemId, item.skill, item.prompt, item.answer, _typeFor(item.skill)));
  }
  return result;
}

QuizPrompt _prompt(String id, Skill skill, String prompt, String answer, QuizType type) => QuizPrompt(
      itemId: id,
      skill: skill,
      type: type,
      prompt: prompt,
      expectedAnswer: answer,
      evaluate: (value) => value.trim() == answer,
      metadata: type == QuizType.listening ? const {'audioRequired': true} : const {},
    );

QuizType _typeFor(Skill skill) => switch (skill) {
      Skill.recognition => QuizType.recognition,
      Skill.production => QuizType.recall,
      Skill.composition => QuizType.composition,
      Skill.listening => QuizType.listening,
      Skill.keyboard => QuizType.keyboard,
      Skill.pinyinConversion => QuizType.recall,
    };
