import 'package:bopomofo/features/review/audio_prompt_player.dart';
import 'package:bopomofo/features/review/question_view.dart';
import 'package:bopomofo/l10n/app_localizations.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_engine/learning_engine.dart';

void main() {
  for (final locale in [
    const Locale('en'),
    const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
    const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
  ]) {
    for (final size in [const Size(320, 480), const Size(568, 320)]) {
      for (final type in QuizType.values) {
        testWidgets('$locale $size ${type.name} remains usable with large text',
            (tester) async {
          await tester.binding.setSurfaceSize(size);
          addTearDown(() => tester.binding.setSurfaceSize(null));
          await tester.pumpWidget(MaterialApp(
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2.5)),
              child: child!,
            ),
            home: Scaffold(
              body: QuestionView(
                prompt: QuizPrompt(
                  id: type.name,
                  itemId: 'ba',
                  skill: Skill.recognition,
                  type: type,
                  promptKey: 'quiz.${type.name}',
                  promptArguments: const {'pinyin': 'ba', 'glyph': 'ㄅ'},
                  expectedAnswer:
                      type == QuizType.composition || type == QuizType.recall
                          ? 'ㄅㄚ'
                          : 'ㄅ',
                  options: type == QuizType.recall
                      ? const ['ㄅㄚ', 'ㄇㄚ']
                      : const ['ㄅ', 'ㄚ', 'ㄇ', 'ㄆ'],
                  audioAssetId: type == QuizType.listening ? 'ba' : null,
                ),
                audioPlayer: _SilentPlayer(),
                disabled: false,
                onSubmit: (_) {},
              ),
            ),
          ));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          if (type == QuizType.composition || type == QuizType.recall) {
            await tester
                .ensureVisible(find.byKey(const ValueKey('quiz-submit')));
            await tester.pumpAndSettle();
            expect(find.byKey(const ValueKey('quiz-submit')).hitTestable(),
                findsOneWidget);
          }
        });
      }
    }
  }
}

class _SilentPlayer implements AudioPromptPlayer {
  @override
  Future<void> play(String assetId) async {}
  @override
  Future<void> dispose() async {}
}
