import 'package:bopomofo/features/lesson/learning_path.dart';
import 'package:bopomofo/features/review/audio_asset_manifest.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_engine/learning_engine.dart';
import 'package:phonology/phonology.dart' as phonology;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('guided lessons reach every zhuyin symbol', () async {
    final manifest = await AudioAssetManifest.loadBundled(rootBundle);
    final taught = <String>{};
    for (final path in LearningPath.values) {
      for (final lesson in lessonsForPath(path)) {
        for (final prompt in starterPromptsForLesson(lesson, manifest)) {
          if (prompt.itemId.startsWith('symbol-')) {
            taught.add(prompt.itemId.substring('symbol-'.length));
          } else if (prompt.type == QuizType.recognition) {
            // Beginner recognition contrasts the initial or final glyph.
            for (final symbol in phonology.symbols) {
              if (symbol.glyph == prompt.expectedAnswer) taught.add(symbol.id);
            }
          }
        }
      }
    }
    final everySymbol = phonology.symbols.map((symbol) => symbol.id).toSet();
    expect(everySymbol.difference(taught), isEmpty,
        reason: 'Guided lessons must introduce all 37 zhuyin symbols');
  });

  test('every guided lesson prompt is answerable with a stable item id',
      () async {
    final manifest = await AudioAssetManifest.loadBundled(rootBundle);
    final seenScopes = <String>{};
    for (final path in LearningPath.values) {
      for (final lesson in lessonsForPath(path)) {
        expect(seenScopes.add(lesson.scope), isTrue);
        final prompts = starterPromptsForLesson(lesson, manifest);
        expect(prompts, isNotEmpty,
            reason: '${lesson.scope} must offer exercises');
        final ids = <String>{};
        for (final prompt in prompts) {
          expect(ids.add(prompt.id), isTrue);
          expect(prompt.evaluate(prompt.expectedAnswer), isTrue);
        }
      }
    }
  });
}
