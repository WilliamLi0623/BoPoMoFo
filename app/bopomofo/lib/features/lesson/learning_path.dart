import 'package:domain/domain.dart';
import 'package:learning_engine/learning_engine.dart';
import 'package:phonology/phonology.dart' as phonology;

import '../review/audio_asset_manifest.dart';
import '../review/starter_question_bank.dart';

enum LearningPath { pinyin, sounds, beginner }

class LearningLesson {
  const LearningLesson(this.path, this.number, this.examples);

  final LearningPath path;
  final int number;
  final List<String> examples;

  // The first lesson uses the key shipped before the course had a lesson list.
  String get scope => number == 1 ? path.name : '${path.name}.lesson-$number';

  bool get hasNext => number < lessonsForPath(path).length;
}

List<LearningLesson> lessonsForPath(LearningPath path) => switch (path) {
      LearningPath.pinyin => const [
          LearningLesson(LearningPath.pinyin, 1, ['ba', 'ma', 'da']),
          LearningLesson(LearningPath.pinyin, 2, ['bo', 'bi', 'bu']),
          LearningLesson(LearningPath.pinyin, 3, ['na', 'la', 'ga', 'ka']),
        ],
      LearningPath.sounds => const [
          LearningLesson(LearningPath.sounds, 1, ['ba', 'ma']),
          LearningLesson(LearningPath.sounds, 2, ['bi', 'bu']),
          LearningLesson(LearningPath.sounds, 3, ['da', 'na']),
        ],
      LearningPath.beginner => const [
          LearningLesson(LearningPath.beginner, 1, ['ba', 'pa', 'ma', 'fa']),
          LearningLesson(LearningPath.beginner, 2, ['ba', 'bo', 'bi', 'bu']),
          LearningLesson(LearningPath.beginner, 3, ['da', 'na', 'la', 'ga']),
        ],
    };

List<QuizPrompt> starterPromptsForPath(
  LearningPath path,
  AudioAssetManifest manifest,
) =>
    starterPromptsForLesson(lessonsForPath(path).first, manifest);

List<QuizPrompt> starterPromptsForLesson(
  LearningLesson lesson,
  AudioAssetManifest manifest,
) {
  if (lesson.path == LearningPath.beginner) return _beginnerPrompts(lesson);

  final type = lesson.path == LearningPath.sounds
      ? QuizType.listening
      : QuizType.composition;
  final itemIds = lesson.examples.map((pinyin) => 'syllable-$pinyin').toSet();
  return buildStarterQuestionBank(manifest)
      .where((prompt) => prompt.type == type && itemIds.contains(prompt.itemId))
      .toList(growable: false);
}

List<QuizPrompt> _beginnerPrompts(LearningLesson lesson) {
  final syllables = lesson.examples.map(phonology.toZhuyin).toList();
  final finalSymbols = lesson.number == 2;
  final choices = syllables
      .map((syllable) => String.fromCharCode(
          finalSymbols ? syllable.runes.last : syllable.runes.first))
      .toList(growable: false);
  return [
    for (var i = 0; i < syllables.length; i++)
      QuizPrompt(
        id: 'beginner-${finalSymbols ? 'final' : 'initial'}-${lesson.examples[i]}',
        itemId: finalSymbols
            ? 'syllable-${lesson.examples[i]}-final'
            : 'syllable-${lesson.examples[i]}',
        skill: Skill.recognition,
        type: QuizType.recognition,
        promptKey: finalSymbols ? 'quiz.beginnerFinal' : 'quiz.beginnerInitial',
        promptArguments: {'syllable': syllables[i]},
        expectedAnswer: choices[i],
        options: choices,
      ),
  ];
}
