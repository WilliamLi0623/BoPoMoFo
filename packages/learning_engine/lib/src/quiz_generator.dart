import 'package:domain/domain.dart';

import 'confusion_engine.dart';

enum QuizType { recognition, recall, composition, listening, keyboard }

class LearningItem {
  final String itemId;
  final String prompt;
  final String answer;
  final Skill skill;

  const LearningItem(
      {required this.itemId,
      required this.prompt,
      required this.answer,
      required this.skill});
}

/// All data needed to render and evaluate a question after a restart.
class QuizPrompt {
  QuizPrompt({
    required this.id,
    required this.itemId,
    required this.skill,
    required this.type,
    required this.promptKey,
    required Map<String, String> promptArguments,
    required this.expectedAnswer,
    required List<String> options,
    this.audioAssetId,
  })  : promptArguments = Map.unmodifiable(promptArguments),
        options = List.unmodifiable(options) {
    _validate();
  }

  final String id;
  final String itemId;
  final Skill skill;
  final QuizType type;
  final String promptKey;
  final Map<String, String> promptArguments;
  final String expectedAnswer;
  final List<String> options;
  final String? audioAssetId;

  bool evaluate(String response) => response.trim() == expectedAnswer;

  void _validate() {
    if (id.trim().isEmpty ||
        itemId.trim().isEmpty ||
        promptKey.trim().isEmpty ||
        expectedAnswer.trim().isEmpty) {
      throw const FormatException('Quiz prompt has an empty required field');
    }
    if (options.length < 2 ||
        options.any((option) => option.trim().isEmpty) ||
        options.toSet().length != options.length) {
      throw const FormatException(
          'Quiz prompt options must be unique and nonempty');
    }
    if (type != QuizType.composition && !options.contains(expectedAnswer)) {
      throw const FormatException(
          'Quiz prompt options omit the correct answer');
    }
    if (type == QuizType.composition) {
      final glyphs = expectedAnswer.runes.map(String.fromCharCode).toList();
      if (glyphs.length != glyphs.toSet().length ||
          !options.toSet().containsAll(glyphs)) {
        throw const FormatException('Composition tiles cannot form the answer');
      }
    }
    if (type == QuizType.listening &&
        (audioAssetId == null || audioAssetId!.isEmpty)) {
      throw const FormatException(
          'Listening prompt requires an audio asset ID');
    }
    if (type != QuizType.listening && audioAssetId != null) {
      throw const FormatException('Only listening prompts may carry audio');
    }
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'itemId': itemId,
        'skill': skill.name,
        'type': type.name,
        'promptKey': promptKey,
        'promptArguments': promptArguments,
        'expectedAnswer': expectedAnswer,
        'options': options,
        'audioAssetId': audioAssetId,
      };

  factory QuizPrompt.fromJson(Map<String, dynamic> json) {
    try {
      final arguments = json['promptArguments'] as Map<String, dynamic>;
      final choices = json['options'] as List<dynamic>;
      return QuizPrompt(
        id: json['id'] as String,
        itemId: json['itemId'] as String,
        skill: Skill.values.byName(json['skill'] as String),
        type: QuizType.values.byName(json['type'] as String),
        promptKey: json['promptKey'] as String,
        promptArguments:
            arguments.map((key, value) => MapEntry(key, value as String)),
        expectedAnswer: json['expectedAnswer'] as String,
        options: choices.cast<String>(),
        audioAssetId: json['audioAssetId'] as String?,
      );
    } on FormatException {
      rethrow;
    } catch (error) {
      throw FormatException('Malformed quiz prompt: $error');
    }
  }
}

class LearningSnapshot {
  final List<ReviewState> reviewStates;
  final List<ConfusionTarget> confusionTargets;
  final List<LearningItem> unlockedItems;

  const LearningSnapshot(
      {this.reviewStates = const [],
      this.confusionTargets = const [],
      this.unlockedItems = const []});
}

class _RankedPrompt {
  const _RankedPrompt(this.prompt, this.group, this.priority, this.order);
  final QuizPrompt prompt;
  final int group;
  final num priority;
  final int order;
}

/// Selects only supplied, answerable prompts. A missing content mapping never
/// becomes a synthetic question.
List<QuizPrompt> nextPrompts(LearningSnapshot snapshot, DateTime now, int limit,
    {List<QuizPrompt> starterPrompts = const []}) {
  if (limit <= 0 || starterPrompts.isEmpty) return const [];

  final due = <String, DateTime>{};
  for (final state in snapshot.reviewStates) {
    if (state.dueAt.isAfter(now)) continue;
    final key = '${state.itemId}|${state.skill.name}';
    final previous = due[key];
    if (previous == null || state.dueAt.isBefore(previous))
      due[key] = state.dueAt;
  }
  final confusion = <String, double>{};
  for (final target in snapshot.confusionTargets) {
    if (target.exposureCount < 1 || target.errorCount < 1) continue;
    final previous = confusion[target.expected];
    if (previous == null || target.errorRate > previous) {
      confusion[target.expected] = target.errorRate;
    }
  }
  final newItems = <String, int>{};
  for (var index = 0; index < snapshot.unlockedItems.length; index++) {
    final item = snapshot.unlockedItems[index];
    newItems.putIfAbsent('${item.itemId}|${item.skill.name}', () => index);
  }

  final ranked = <_RankedPrompt>[];
  for (var index = 0; index < starterPrompts.length; index++) {
    final prompt = starterPrompts[index];
    final itemKey = '${prompt.itemId}|${prompt.skill.name}';
    final dueAt = due[itemKey];
    if (dueAt != null) {
      ranked.add(_RankedPrompt(prompt, 0, dueAt.microsecondsSinceEpoch, index));
    } else if (confusion.containsKey(prompt.expectedAnswer)) {
      ranked.add(
          _RankedPrompt(prompt, 1, -confusion[prompt.expectedAnswer]!, index));
    } else {
      ranked.add(_RankedPrompt(prompt, 2,
          newItems[itemKey] ?? snapshot.unlockedItems.length + index, index));
    }
  }
  ranked.sort((a, b) {
    final group = a.group.compareTo(b.group);
    if (group != 0) return group;
    final priority = a.priority.compareTo(b.priority);
    return priority != 0 ? priority : a.order.compareTo(b.order);
  });

  final selected = <QuizPrompt>[];
  final usedIds = <String>{};
  final usedTuples = <(String, Skill, QuizType)>{};
  void add(QuizPrompt prompt) {
    if (selected.length >= limit || usedIds.contains(prompt.id)) return;
    final tuple = (prompt.itemId, prompt.skill, prompt.type);
    if (usedTuples.contains(tuple)) return;
    usedIds.add(prompt.id);
    usedTuples.add(tuple);
    selected.add(prompt);
  }

  for (final type in QuizType.values) {
    var reserved = 0;
    for (final entry in ranked) {
      if (reserved == 2 || selected.length == limit) break;
      if (entry.prompt.type != type) continue;
      final before = selected.length;
      add(entry.prompt);
      if (selected.length > before) reserved++;
    }
  }
  for (final entry in ranked) {
    if (selected.length == limit) break;
    add(entry.prompt);
  }
  return List.unmodifiable(selected);
}
