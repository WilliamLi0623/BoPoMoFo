import 'package:bopomofo/features/review/audio_asset_manifest.dart';
import 'package:bopomofo/features/review/starter_question_bank.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_engine/learning_engine.dart';
import 'package:phonology/phonology.dart' as phonology;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('real starter bank supplies two answerable prompts for every type',
      () async {
    final manifest = await AudioAssetManifest.load(rootBundle);
    final prompts = buildStarterQuestionBank(manifest);

    for (final type in QuizType.values) {
      expect(prompts.where((prompt) => prompt.type == type).length,
          greaterThanOrEqualTo(2),
          reason: type.name);
    }
    expect(
        prompts.map((prompt) => prompt.id).toSet(), hasLength(prompts.length));
    for (final prompt in prompts) {
      expect(prompt.evaluate(prompt.expectedAnswer), isTrue);
      expect(prompt.options.toSet(), hasLength(prompt.options.length));
      if (prompt.type == QuizType.composition) {
        for (final glyph
            in prompt.expectedAnswer.runes.map(String.fromCharCode)) {
          expect(prompt.options, contains(glyph));
        }
      } else {
        expect(prompt.options, contains(prompt.expectedAnswer));
      }
      if (prompt.type == QuizType.listening) {
        final matching =
            manifest.entries.where((entry) => entry.id == prompt.audioAssetId);
        expect(matching, hasLength(1));
        expect(matching.single.expectedAnswer, prompt.expectedAnswer);
        expect(
            phonology.toZhuyin(matching.single.pinyin), prompt.expectedAnswer);
      } else {
        expect(prompt.audioAssetId, isNull);
      }
    }
  });

  test('listening requires a verified matching manifest entry', () async {
    final manifest = await AudioAssetManifest.load(rootBundle);
    final wrong = AudioAssetEntry(
      id: manifest.entries.first.id,
      pinyin: manifest.entries.first.pinyin,
      expectedAnswer: '\u3107\u311a',
      assetPath: manifest.entries.first.assetPath,
      sourceArchiveEntry: manifest.entries.first.sourceArchiveEntry,
      attribution: manifest.entries.first.attribution,
      sourceUrl: manifest.entries.first.sourceUrl,
      license: manifest.entries.first.license,
    );
    final bank = buildStarterQuestionBank(AudioAssetManifest([wrong]));
    expect(bank.where((prompt) => prompt.type == QuizType.listening), isEmpty);
  });
}
