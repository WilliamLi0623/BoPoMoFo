import 'dart:async';

import 'package:bopomofo/features/review/audio_prompt_player.dart';
import 'package:bopomofo/features/review/question_view.dart';
import 'package:bopomofo/features/review/review_page.dart';
import 'package:bopomofo/l10n/app_localizations.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_engine/learning_engine.dart';
import 'package:persistence/persistence.dart';

import '../test_support.dart';

void main() {
  final locales = [
    (
      locale: const Locale('en'),
      prompt: 'Which sound does ㄅ represent?',
      recall: 'Enter the Bopomofo for ba.',
      composition: 'Build the Bopomofo syllable for ba.',
      listening: 'Listen and choose the Bopomofo transcription.',
      keyboard: 'Type the Bopomofo for ba.',
      select: 'Select answer ba',
      add: 'Add symbol ㄅ',
      type: 'Type ㄅ using key 1',
      progress: 'Question 1 of 1',
      correct: 'Correct answer saved locally.',
      incorrect: 'Answer saved locally. Keep practicing.',
      audio: 'Play question audio',
      playing: 'Playing question audio',
      audioError: 'Audio could not be played. Try again.',
      emptyComposition: 'No symbols selected',
      answer: 'Current answer: ㄅ',
      error: 'Could not save or load your review. Try again.',
      completion: 'Review complete: 1 / 1 correct.',
    ),
    (
      locale: const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
      prompt: '这个符号代表什么读音？ㄅ',
      recall: '输入 ba 对应的注音。',
      composition: '用注音符号组成 ba。',
      listening: '聆听发音并选择对应的注音。',
      keyboard: '输入 ba 对应的注音符号。',
      select: '选择答案 ba',
      add: '添加符号 ㄅ',
      type: '使用按键 1 输入符号 ㄅ',
      progress: '第 1 题，共 1 题',
      correct: '回答正确，已保存到本机。',
      incorrect: '答案已保存到本机。继续练习。',
      audio: '播放题目音频',
      playing: '正在播放题目音频',
      audioError: '无法播放音频，请重试。',
      emptyComposition: '尚未选择符号',
      answer: '当前答案：ㄅ',
      error: '无法保存或载入复习进度。请重试。',
      completion: '复习完成：答对 1 / 1 题。',
    ),
    (
      locale: const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
      prompt: '這個符號代表什麼讀音？ㄅ',
      recall: '輸入 ba 對應的注音。',
      composition: '用注音符號組成 ba。',
      listening: '聆聽發音並選擇對應的注音。',
      keyboard: '輸入 ba 對應的注音符號。',
      select: '選擇答案 ba',
      add: '新增符號 ㄅ',
      type: '使用按鍵 1 輸入符號 ㄅ',
      progress: '第 1 題，共 1 題',
      correct: '回答正確，已儲存到本機。',
      incorrect: '答案已儲存到本機。繼續練習。',
      audio: '播放題目音訊',
      playing: '正在播放題目音訊',
      audioError: '無法播放音訊，請重試。',
      emptyComposition: '尚未選擇符號',
      answer: '目前答案：ㄅ',
      error: '無法儲存或載入複習進度。請重試。',
      completion: '複習完成：答對 1 / 1 題。',
    ),
  ];

  for (final language in locales) {
    testWidgets('${language.locale} exposes all five question controls',
        (tester) async {
      final handle = tester.ensureSemantics();
      for (final type in QuizType.values) {
        await _pump(
            tester,
            language.locale,
            QuestionView(
              key: ValueKey(type.name),
              prompt: _prompt(type),
              audioPlayer: FakeAudioPromptPlayer(),
              onSubmit: (_) {},
              disabled: false,
            ));
        expect(
            find.byKey(const ValueKey('quiz-question-prompt')), findsOneWidget);
        expect(find.textContaining('Answer the question using the controls.'),
            findsNothing);
        switch (type) {
          case QuizType.recognition:
            expect(find.text(language.prompt), findsOneWidget);
            expect(
                find.byKey(const ValueKey('quiz-option-ba')), findsOneWidget);
            expect(find.bySemanticsLabel(language.select), findsOneWidget);
          case QuizType.recall:
            expect(find.text(language.recall), findsOneWidget);
            expect(find.byKey(const ValueKey('quiz-recall-input')),
                findsOneWidget);
            expect(find.byKey(const ValueKey('quiz-submit')), findsOneWidget);
          case QuizType.composition:
            expect(find.text(language.composition), findsOneWidget);
            expect(find.bySemanticsLabel(language.emptyComposition),
                findsOneWidget);
            expect(find.bySemanticsLabel(language.add), findsOneWidget);
            await tester.tap(find.byKey(const ValueKey('quiz-tile-ㄅ')));
            await tester.pump();
            expect(find.bySemanticsLabel(language.answer), findsOneWidget);
          case QuizType.listening:
            expect(find.text(language.listening), findsOneWidget);
            expect(find.bySemanticsLabel(language.audio), findsOneWidget);
            expect(
                find.byKey(const ValueKey('quiz-option-ㄅㄚ')), findsOneWidget);
          case QuizType.keyboard:
            expect(find.text(language.keyboard), findsOneWidget);
            expect(find.byKey(const ValueKey('quiz-key-1')), findsOneWidget);
            expect(find.bySemanticsLabel(language.type), findsOneWidget);
        }
        if (language.locale.languageCode == 'zh') {
          for (final fallback in [
            'Select answer',
            'Enter your response',
            'Submit answer',
            'Add symbol',
            'Play question audio',
            'Type ㄅ using key',
          ]) {
            expect(find.bySemanticsLabel(RegExp(fallback)), findsNothing);
          }
        }
      }
      handle.dispose();
    });

    testWidgets('${language.locale} announces fake audio failure and playback',
        (tester) async {
      final handle = tester.ensureSemantics();
      final player = _FakeControlledAudio();
      await _pump(
          tester,
          language.locale,
          QuestionView(
            prompt: _prompt(QuizType.listening),
            audioPlayer: player,
            onSubmit: (_) {},
            disabled: false,
          ));
      await tester.tap(find.byKey(const ValueKey('quiz-play-audio')));
      await tester.pump();
      expect(find.bySemanticsLabel(language.playing), findsOneWidget);
      player.completeWithError();
      await tester.pump();
      expect(find.text(language.audioError), findsOneWidget);
      expect(_liveRegionWithLabel(language.audioError), findsOneWidget);
      expect(find.bySemanticsLabel(language.audio), findsOneWidget);
      handle.dispose();
    });

    testWidgets('${language.locale} announces progress, results and completion',
        (tester) async {
      final handle = tester.ensureSemantics();
      final repository = await LocalLearningRepository.inMemory(
          userId: 'a11y-${language.locale}');
      addTearDown(repository.close);
      await _pumpReview(
          tester,
          language.locale,
          createTestReviewSessionFactory(
              store: repository, prompts: [_prompt(QuizType.recognition)]));

      expect(find.text(language.prompt), findsOneWidget);
      expect(find.bySemanticsLabel(language.progress), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('quiz-option-pa')));
      await tester.pumpAndSettle();
      expect(find.text(language.incorrect), findsOneWidget);
      expect(_liveRegionWithLabel(language.incorrect), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('quiz-continue')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('quiz-completion')), findsOneWidget);
      expect(_liveRegionWithLabel('0 / 1'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('quiz-start-again')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('quiz-option-ba')));
      await tester.pumpAndSettle();
      expect(_liveRegionWithLabel(language.correct), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('quiz-continue')));
      await tester.pumpAndSettle();
      expect(find.text(language.completion), findsOneWidget);
      handle.dispose();
    });

    testWidgets('${language.locale} exposes a localized storage failure',
        (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpReview(tester, language.locale,
          () async => throw StateError('private storage detail'));
      expect(find.text(language.error), findsOneWidget);
      expect(_liveRegionWithLabel(language.error), findsOneWidget);
      expect(find.textContaining('private storage detail'), findsNothing);
      handle.dispose();
    });
  }
}

Finder _liveRegionWithLabel(String text) => find.byWidgetPredicate((widget) =>
    widget is Semantics &&
    widget.properties.liveRegion == true &&
    (widget.properties.label?.contains(text) ?? false));

Future<void> _pump(WidgetTester tester, Locale locale, Widget child) async {
  await tester.pumpWidget(MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: const [
      Locale('en'),
      Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
      Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
    ],
    home: Scaffold(body: child),
  ));
  await tester.pumpAndSettle();
}

Future<void> _pumpReview(
        WidgetTester tester, Locale locale, ReviewSessionFactory factory) =>
    _pump(tester, locale, ReviewPage(sessionFactory: factory));

QuizPrompt _prompt(QuizType type) => QuizPrompt(
      id: 'accessibility-${type.name}',
      itemId: 'ba',
      skill: Skill.recognition,
      type: type,
      promptKey: 'quiz.${type.name}',
      promptArguments: switch (type) {
        QuizType.recognition => const {'glyph': 'ㄅ'},
        QuizType.listening => const {},
        _ => const {'pinyin': 'ba'},
      },
      expectedAnswer: switch (type) {
        QuizType.recognition => 'ba',
        QuizType.keyboard => 'ㄅ',
        _ => 'ㄅㄚ',
      },
      options: switch (type) {
        QuizType.recognition => const ['ba', 'pa'],
        QuizType.recall => const ['ㄅㄚ', 'ㄆㄚ'],
        QuizType.composition => const ['ㄅ', 'ㄚ'],
        QuizType.listening => const ['ㄅㄚ', 'ㄆㄚ'],
        QuizType.keyboard => const ['ㄅ', 'ㄆ'],
      },
      audioAssetId: type == QuizType.listening ? 'fake-ba' : null,
    );

class _FakeControlledAudio implements AudioPromptPlayer {
  final _playback = Completer<void>();

  @override
  Future<void> play(String assetId) => _playback.future;

  void completeWithError() => _playback.completeError(
      const AudioPromptPlaybackException(message: 'fake failure'));

  @override
  Future<void> dispose() async {}
}
