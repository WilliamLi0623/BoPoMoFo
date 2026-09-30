import 'package:domain/domain.dart';
import 'package:learning_engine/learning_engine.dart';
import 'package:phonology/phonology.dart' as phonology;

import 'audio_asset_manifest.dart';

// Pinyin keys are checked through phonology.toZhuyin before use. This is a
// curated subset of the mappings in packages/phonology, not a new mapping.
const _syllableKeys = <String>[
  'ba',
  'ma',
  'bo',
  'bi',
  'bu',
  'da',
  'de',
  'di',
  'du',
  'ga',
  'ge',
  'gu',
  'ka',
  'la',
  'le',
  'li',
  'lu',
  'na',
  'ne',
  'ni',
  'nu',
];

List<String> _choices(String correct, Iterable<String> domain) {
  final unique = <String>{correct};
  for (final option in domain) {
    if (unique.length == 4) break;
    unique.add(option);
  }
  return List.unmodifiable(unique);
}

/// Builds only questions backed by the checked symbol inventory and mappings.
List<QuizPrompt> buildStarterQuestionBank(AudioAssetManifest manifest) {
  final result = <QuizPrompt>[];
  final symbolGlyphs = phonology.symbols.map((symbol) => symbol.glyph).toList();
  for (final symbol in phonology.symbols) {
    final name = symbol.pinyin;
    if (name == null || name.isEmpty) continue;
    final peers = phonology.symbols
        .where((other) => other.category == symbol.category)
        .toList();
    result.add(QuizPrompt(
      id: 'recognition-${symbol.id}',
      itemId: 'symbol-${symbol.id}',
      skill: Skill.recognition,
      type: QuizType.recognition,
      promptKey: 'quiz.recognition',
      promptArguments: {'glyph': symbol.glyph},
      expectedAnswer: name,
      options: _choices(name, peers.map((other) => other.pinyin ?? other.id)),
    ));
    result.add(QuizPrompt(
      id: 'recall-${symbol.id}',
      itemId: 'symbol-${symbol.id}',
      skill: Skill.production,
      type: QuizType.recall,
      promptKey: 'quiz.recall',
      promptArguments: {'pinyin': name},
      expectedAnswer: symbol.glyph,
      options: _choices(symbol.glyph, peers.map((other) => other.glyph)),
    ));
    result.add(QuizPrompt(
      id: 'keyboard-${symbol.id}',
      itemId: 'symbol-${symbol.id}',
      skill: Skill.keyboard,
      type: QuizType.keyboard,
      promptKey: 'quiz.keyboard',
      promptArguments: {'pinyin': name},
      expectedAnswer: symbol.glyph,
      options: _choices(symbol.glyph, peers.map((other) => other.glyph)),
    ));
  }

  final syllables = <String, String>{};
  for (final pinyin in _syllableKeys) {
    try {
      final zhuyin = phonology.toZhuyin(pinyin);
      if (zhuyin.runes.length > 1) syllables[pinyin] = zhuyin;
    } on phonology.UnknownPinyinError {
      // An absent mapping is ineligible; never infer one from spelling.
    }
  }
  final syllableAnswers = syllables.values.toSet();
  for (final entry in syllables.entries) {
    final tiles = entry.value.runes.map(String.fromCharCode).toSet();
    final distractor = symbolGlyphs.firstWhere(
      (glyph) => !tiles.contains(glyph),
      orElse: () => '',
    );
    if (distractor.isEmpty) continue;
    result.add(QuizPrompt(
      id: 'composition-${entry.key}',
      itemId: 'syllable-${entry.key}',
      skill: Skill.composition,
      type: QuizType.composition,
      promptKey: 'quiz.composition',
      promptArguments: {'pinyin': entry.key},
      expectedAnswer: entry.value,
      options: [...tiles, distractor],
    ));
  }

  final usedAudioIds = <String>{};
  for (final entry in manifest.entries) {
    if (entry.id.isEmpty ||
        !usedAudioIds.add(entry.id) ||
        !entry.assetPath.startsWith('assets/audio/') ||
        entry.sourceArchiveEntry.isEmpty ||
        entry.license != 'Government Open Data License, Version 1.0' ||
        entry.sourceUrl != 'https://www.cns11643.gov.tw/opendata/Voice.zip' ||
        manifest.assetPathForId(entry.id) != entry.assetPath) {
      continue;
    }
    final expected = syllables[entry.pinyin];
    if (expected == null ||
        expected != entry.expectedAnswer ||
        !syllableAnswers.contains(expected)) continue;
    result.add(QuizPrompt(
      id: 'listening-${entry.id}',
      itemId: 'syllable-${entry.pinyin}',
      skill: Skill.listening,
      type: QuizType.listening,
      promptKey: 'quiz.listening',
      promptArguments: const {},
      expectedAnswer: expected,
      options: _choices(expected, syllableAnswers),
      audioAssetId: entry.id,
    ));
  }
  return List.unmodifiable(result);
}
