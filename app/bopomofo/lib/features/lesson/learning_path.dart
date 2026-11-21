import 'package:domain/domain.dart';
import 'package:learning_engine/learning_engine.dart';
import 'package:phonology/phonology.dart' as phonology;

import '../review/audio_asset_manifest.dart';
import '../review/starter_question_bank.dart';

enum LearningPath { pinyin, sounds, beginner }

class LearningLesson {
  const LearningLesson(this.path, this.number, this.examples,
      {this.finalFocus = false});

  final LearningPath path;
  final int number;
  final List<String> examples;

  /// Beginner lessons contrast either the initial or the final symbol of
  /// each example syllable.
  final bool finalFocus;

  // The first lesson uses the key shipped before the course had a lesson list.
  String get scope => number == 1 ? path.name : '${path.name}.lesson-$number';

  bool get hasNext => number < lessonsForPath(path).length;
}

List<LearningLesson> lessonsForPath(LearningPath path) => switch (path) {
      LearningPath.pinyin => const [
          LearningLesson(LearningPath.pinyin, 1, ['ba', 'ma', 'da']),
          LearningLesson(LearningPath.pinyin, 2, ['bo', 'bi', 'bu']),
          LearningLesson(LearningPath.pinyin, 3, ['na', 'la', 'ga', 'ka']),
          LearningLesson(LearningPath.pinyin, 4, ['ta', 'te', 'he', 'de']),
          LearningLesson(LearningPath.pinyin, 5, ['ji', 'qi', 'xi', 'ju']),
          LearningLesson(LearningPath.pinyin, 6, ['zhi', 'chi', 'shi', 'ri']),
          LearningLesson(LearningPath.pinyin, 7,
              ['zi', 'ci', 'si', 'bai', 'bei', 'bao']),
          LearningLesson(LearningPath.pinyin, 8,
              ['ban', 'ben', 'bang', 'deng', 'er']),
        ],
      LearningPath.sounds => const [
          LearningLesson(LearningPath.sounds, 1, ['ba', 'ma']),
          LearningLesson(LearningPath.sounds, 2, ['bi', 'bu']),
          LearningLesson(LearningPath.sounds, 3, ['da', 'na']),
          LearningLesson(LearningPath.sounds, 4, ['he', 'ta']),
          LearningLesson(LearningPath.sounds, 5, ['ji', 'xi']),
          LearningLesson(LearningPath.sounds, 6, ['bai', 'bao']),
        ],
      LearningPath.beginner => const [
          LearningLesson(LearningPath.beginner, 1, ['ba', 'pa', 'ma', 'fa']),
          LearningLesson(LearningPath.beginner, 2, ['ba', 'bo', 'bi', 'bu'],
              finalFocus: true),
          LearningLesson(LearningPath.beginner, 3, ['da', 'na', 'la', 'ga']),
          LearningLesson(LearningPath.beginner, 4, ['he', 'ji', 'qi', 'xi']),
          LearningLesson(LearningPath.beginner, 5, ['zhi', 'chi', 'shi', 'ri']),
          LearningLesson(LearningPath.beginner, 6, ['zi', 'ci', 'si', 'ta']),
          LearningLesson(LearningPath.beginner, 7, ['ju', 'qu', 'xu', 'yu']),
          LearningLesson(LearningPath.beginner, 8,
              ['bai', 'bei', 'bao', 'dou', 'ye'],
              finalFocus: true),
          LearningLesson(LearningPath.beginner, 9,
              ['ban', 'ben', 'bang', 'deng', 'er'],
              finalFocus: true),
        ],
    };

/// Every zhuyin symbol that the lesson's example syllables contain.
Set<String> _taughtSymbolIds(LearningLesson lesson) {
  final ids = <String>{};
  for (final example in lesson.examples) {
    for (final rune in phonology.toZhuyin(example).runes) {
      final glyph = String.fromCharCode(rune);
      for (final symbol in phonology.symbols) {
        if (symbol.glyph == glyph) ids.add(symbol.id);
      }
    }
  }
  return ids;
}

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
  // Pinyin lessons also teach writing and typing for every zhuyin symbol
  // their syllables contain, so the guided course reaches the full
  // 37-symbol inventory.
  final symbolIds = lesson.path == LearningPath.pinyin
      ? _taughtSymbolIds(lesson)
      : const <String>{};
  const symbolPrefix = 'symbol-';
  return buildStarterQuestionBank(manifest)
      .where((prompt) =>
          (prompt.type == type && itemIds.contains(prompt.itemId)) ||
          (symbolIds.isNotEmpty &&
              (prompt.type == QuizType.recall ||
                      prompt.type == QuizType.keyboard) &&
                  prompt.itemId.startsWith(symbolPrefix) &&
                  symbolIds.contains(prompt.itemId.substring(symbolPrefix.length))))
      .toList(growable: false);
}

List<QuizPrompt> _beginnerPrompts(LearningLesson lesson) {
  final syllables = lesson.examples.map(phonology.toZhuyin).toList();
  final finalSymbols = lesson.finalFocus;
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
