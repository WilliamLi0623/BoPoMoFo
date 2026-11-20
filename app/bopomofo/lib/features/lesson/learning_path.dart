import 'package:domain/domain.dart';
import 'package:learning_engine/learning_engine.dart';
import 'package:phonology/phonology.dart' as phonology;

import '../review/audio_asset_manifest.dart';
import '../review/starter_question_bank.dart';

enum LearningPath { pinyin, sounds, beginner }

const pinyinLessonExamples = ['ba', 'ma', 'da'];
const beginnerLessonExamples = ['ba', 'pa', 'ma', 'fa'];

List<QuizPrompt> starterPromptsForPath(
  LearningPath path,
  AudioAssetManifest manifest,
) {
  if (path == LearningPath.beginner) return _beginnerPrompts();
  final types = path == LearningPath.sounds
      ? const {QuizType.listening}
      : const {QuizType.recall, QuizType.composition, QuizType.keyboard};
  return buildStarterQuestionBank(manifest)
      .where((prompt) => types.contains(prompt.type))
      .toList(growable: false);
}

List<QuizPrompt> _beginnerPrompts() {
  final samples = beginnerLessonExamples.map(phonology.toZhuyin).toList();
  final initials = samples
      .map((syllable) => String.fromCharCode(syllable.runes.first))
      .toList(growable: false);
  return [
    for (var i = 0; i < samples.length; i++)
      QuizPrompt(
        id: 'beginner-initial-${beginnerLessonExamples[i]}',
        itemId: 'syllable-${beginnerLessonExamples[i]}',
        skill: Skill.recognition,
        type: QuizType.recognition,
        promptKey: 'quiz.beginnerInitial',
        promptArguments: {'syllable': samples[i]},
        expectedAnswer: initials[i],
        options: initials,
      ),
  ];
}
