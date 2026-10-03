import 'dart:convert';
import 'dart:io';

import 'package:bopomofo/features/review/review_page.dart';
import 'package:bopomofo/features/review/audio_asset_manifest.dart';
import 'package:bopomofo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:domain/domain.dart';
import 'package:learning_engine/learning_engine.dart';
import 'package:persistence/persistence.dart';

import '../test_support.dart';

void main() {
  for (final language in [
    (
      locale: const Locale('en'),
      prefix: 'Correct answer: ',
      notice: 'Answer saved locally. Keep practicing.'
    ),
    (
      locale: const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
      prefix: '正确答案：',
      notice: '答案已保存到本机。继续练习。'
    ),
    (
      locale: const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
      prefix: '正確答案：',
      notice: '答案已儲存到本機。繼續練習。'
    ),
  ]) {
    for (final type in QuizType.values) {
      testWidgets(
          'saved incorrect ${type.name} shows localized correction in ${language.locale}',
          (tester) async {
        final repository = await LocalLearningRepository.inMemory();
        addTearDown(repository.close);
        final answer = switch (type) {
          QuizType.recognition => 'ba',
          QuizType.keyboard => 'ㄅ',
          _ => 'ㄅㄚ',
        };
        final prompt = QuizPrompt(
          id: 'correction-${type.name}',
          itemId: 'ba',
          skill: Skill.recognition,
          type: type,
          promptKey: 'quiz.${type.name}',
          promptArguments: const {'glyph': 'ㄅ', 'pinyin': 'ba'},
          expectedAnswer: answer,
          options: type == QuizType.composition
              ? const ['ㄅ', 'ㄚ']
              : [answer, 'wrong'],
          audioAssetId: type == QuizType.listening ? 'fake-ba' : null,
        );
        final factory = createTestReviewSessionFactory(
            store: repository, prompts: [prompt]);
        final runtime = await factory();
        await runtime.coordinator.loadOrStartSession();
        await runtime.coordinator.submitAnswer('wrong');
        await runtime.audioPlayer.dispose();
        final saved = (await repository.loadActiveSession())!.toJson();
        final history = await repository.exportLearningData();
        await _pumpReview(tester, factory, locale: language.locale);
        final correction = '${language.prefix}$answer';
        expect(find.text(correction), findsOneWidget);
        expect(find.text(language.notice), findsOneWidget);
        expect(
            find.byWidgetPredicate((widget) =>
                widget is Semantics &&
                widget.properties.liveRegion == true &&
                (widget.properties.label?.contains(language.notice) ?? false) &&
                (widget.properties.label?.contains(correction) ?? false)),
            findsOneWidget);
        expect((await repository.loadActiveSession())!.toJson(), saved);
        expect(await repository.exportLearningData(), history);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }

  for (final locale in [
    (
      value: const Locale('en'),
      notice:
          'Your previous review could not be restored. Your learning history is safe.',
    ),
    (
      value: const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
      notice: '无法恢复上次的复习。你的学习记录已保留。',
    ),
    (
      value: const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
      notice: '無法恢復上次的複習。你的學習紀錄已保留。',
    ),
  ]) {
    for (final corruption in ['malformed', 'codec', 'content']) {
      testWidgets(
          '$corruption session recovery is visible in ${locale.value} and retains history',
          (tester) async {
        final repository =
            await LocalLearningRepository.inMemory(userId: 'review-recovery');
        addTearDown(repository.close);
        final factory = createTestReviewSessionFactory(store: repository);
        final runtime = await factory();
        final original = (await runtime.coordinator.loadOrStartSession())!;
        await runtime.coordinator.submitAnswer('ba');
        await runtime.audioPlayer.dispose();
        final history = await repository.exportLearningData();
        final rows = await repository.database.select(
            'SELECT value FROM settings WHERE key = ?', ['quiz.activeSession']);
        final saved =
            jsonDecode(rows.single['value'] as String) as Map<String, dynamic>;
        final invalid = switch (corruption) {
          'malformed' => '{invalid JSON',
          'codec' => jsonEncode({...saved, 'codecVersion': 999}),
          _ => jsonEncode({...saved, 'contentVersion': 'removed-content'}),
        };
        await repository.database.execute(
            'UPDATE settings SET value = ? WHERE key = ?',
            [invalid, 'quiz.activeSession']);

        await _pumpReview(tester, factory, locale: locale.value);

        expect(find.byKey(const ValueKey('quiz-session-recovery')),
            findsOneWidget);
        expect(find.text(locale.notice), findsOneWidget);
        expect(find.text('1 / 2'), findsOneWidget);
        expect(
            find.byKey(const ValueKey('quiz-answer-feedback')), findsNothing);
        final replacement = (await repository.loadActiveSession())!;
        expect(replacement.id, isNot(original.id));
        expect(replacement.currentIndex, 0);
        expect(replacement.currentAnswer, isNull);
        expect(await repository.exportLearningData(), history);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
    for (final answered in [false, true]) {
      testWidgets(
          'missing queued audio replaces ${answered ? 'answered' : 'unanswered'} session in ${locale.value} and retains history',
          (tester) async {
        final repository = await LocalLearningRepository.inMemory();
        addTearDown(repository.close);
        final manifest =
            (await tester.runAsync(() => AudioAssetManifest.load(rootBundle)))!;
        expect(manifest.assetPathForId('removed-audio'), isNull);
        await repository.saveNewSession(_sessionWithAudio('removed-audio'));
        // The unavailable audio is later in the queue, not the current prompt.
        if (answered) {
          await repository.submitAnswer(
            sessionId: 'saved-audio-session',
            expectedIndex: 0,
            response: 'ba',
            correct: true,
            occurredAt: DateTime.utc(2026, 10, 1),
            latencyMs: 100,
          );
        } else {
          await repository.recordReview(ReviewAttempt(
            itemId: 'prior-history',
            skill: Skill.recognition,
            correct: true,
            occurredAt: DateTime.utc(2026, 9, 30),
          ));
        }
        final history = await repository.exportLearningData();

        await _pumpReview(
            tester,
            createTestReviewSessionFactory(
                store: repository, manifest: manifest),
            locale: locale.value);

        final replacement = (await repository.loadActiveSession())!;
        expect(replacement.id, isNot('saved-audio-session'));
        expect(replacement.prompts.map((prompt) => prompt.id),
            ['first', 'second']);
        expect(replacement.currentIndex, 0);
        expect(replacement.currentAnswer, isNull);
        expect(find.text(locale.notice), findsOneWidget);
        expect(find.byKey(const ValueKey('quiz-session-recovery')),
            findsOneWidget);
        expect(await repository.exportLearningData(), history);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }

  for (final answered in [false, true]) {
    testWidgets('valid audio queue resumes exactly when answered=$answered',
        (tester) async {
      final repository = await LocalLearningRepository.inMemory();
      addTearDown(repository.close);
      final manifest =
          (await tester.runAsync(() => AudioAssetManifest.load(rootBundle)))!;
      expect(manifest.assetPathForId('cns11643-female-ba'), isNotNull);
      await repository.saveNewSession(_sessionWithAudio('cns11643-female-ba'));
      if (answered) {
        await repository.submitAnswer(
          sessionId: 'saved-audio-session',
          expectedIndex: 0,
          response: 'ba',
          correct: true,
          occurredAt: DateTime.utc(2026, 10, 1),
          latencyMs: 100,
        );
      }
      final saved = (await repository.loadActiveSession())!.toJson();
      final history = await repository.exportLearningData();
      await _pumpReview(
          tester,
          createTestReviewSessionFactory(
              store: repository, prompts: [], manifest: manifest));
      expect((await repository.loadActiveSession())!.toJson(), saved);
      expect(await repository.exportLearningData(), history);
      expect(find.byKey(const ValueKey('quiz-session-recovery')), findsNothing);
      expect(find.byKey(const ValueKey('quiz-answer-feedback')),
          answered ? findsOneWidget : findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('answer, continue and completion follow the saved queue',
      (tester) async {
    final repository =
        await LocalLearningRepository.inMemory(userId: 'review-flow');
    addTearDown(repository.close);
    await _pumpReview(
        tester, createTestReviewSessionFactory(store: repository));

    expect(find.text('1 / 2'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('quiz-option-ba')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('quiz-answer-feedback')), findsOneWidget);
    final feedback =
        tester.getRect(find.byKey(const ValueKey('quiz-answer-feedback')));
    final next = tester.getRect(find.byKey(const ValueKey('quiz-continue')));
    expect(next.top - feedback.bottom, greaterThanOrEqualTo(16));
    expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('quiz-continue')));
    await tester.pumpAndSettle();
    expect(find.text('2 / 2'), findsOneWidget);
    expect(find.textContaining('ㄆ'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('quiz-option-pa')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('quiz-continue')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('quiz-completion')), findsOneWidget);
    expect(find.textContaining('2 / 2'), findsWidgets);
    final summary =
        tester.getRect(find.byKey(const ValueKey('quiz-completion')));
    final restart =
        tester.getRect(find.byKey(const ValueKey('quiz-start-again')));
    final returnButton =
        tester.getRect(find.byKey(const ValueKey('quiz-return-to-learning')));
    expect(restart.top - summary.bottom, greaterThanOrEqualTo(24));
    expect(returnButton.top - restart.bottom, greaterThanOrEqualTo(12));
    expect(await repository.loadActiveSession(), isNull);
    await tester.tap(find.byKey(const ValueKey('quiz-start-again')));
    await tester.pumpAndSettle();
    expect(find.text('1 / 2'), findsOneWidget);
    expect(find.byKey(const ValueKey('quiz-answer-feedback')), findsNothing);
    expect((await repository.loadActiveSession())?.currentIndex, 0);
  });

  testWidgets('empty eligible bank shows an empty state', (tester) async {
    final repository =
        await LocalLearningRepository.inMemory(userId: 'review-empty');
    addTearDown(repository.close);
    await _pumpReview(
        tester, createTestReviewSessionFactory(store: repository, prompts: []));
    expect(find.byKey(const ValueKey('quiz-empty')), findsOneWidget);
    expect(find.byKey(const ValueKey('quiz-progress')), findsNothing);
  });

  testWidgets('storage startup failure can be retried', (tester) async {
    final repository =
        await LocalLearningRepository.inMemory(userId: 'review-retry');
    addTearDown(repository.close);
    final healthyFactory = createTestReviewSessionFactory(store: repository);
    var fail = true;
    await _pumpReview(tester, () {
      if (fail) {
        fail = false;
        throw StateError('temporary storage failure');
      }
      return healthyFactory();
    });
    expect(find.byKey(const ValueKey('quiz-storage-error')), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('1 / 2'), findsOneWidget);
    expect(find.byKey(const ValueKey('quiz-storage-error')), findsNothing);
  });

  testWidgets('relaunch restores answered feedback and then next queued prompt',
      (tester) async {
    // File creation and SQLite open use real asynchronous I/O.
    final directory = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('bopomofo-review-widget-')))!;
    addTearDown(() => directory.delete(recursive: true));
    final path = '${directory.path}${Platform.pathSeparator}review.sqlite';
    Future<LocalLearningRepository> open() async {
      final database = LocalDatabase.atPath(path);
      await database.open();
      return LocalLearningRepository(
          database: database, userId: 'review-resume');
    }

    var repository = (await tester.runAsync(open))!;
    await _pumpReview(
        tester, createTestReviewSessionFactory(store: repository));
    final unanswered = (await repository.loadActiveSession())!;
    expect(unanswered.currentAnswer, isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(repository.close);

    repository = (await tester.runAsync(open))!;
    await _pumpReview(
        tester, createTestReviewSessionFactory(store: repository, prompts: []));
    expect(find.text('1 / 2'), findsOneWidget);
    expect(find.byKey(const ValueKey('quiz-option-ba')), findsOneWidget);
    expect((await repository.loadActiveSession())!.prompts.map((p) => p.id),
        ['first', 'second']);
    await tester.tap(find.byKey(const ValueKey('quiz-option-ba')));
    await tester.pumpAndSettle();
    final original = (await repository.loadActiveSession())!;
    expect(original.currentAnswer?.response, 'ba');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(repository.close);

    repository = (await tester.runAsync(open))!;
    await _pumpReview(
        tester, createTestReviewSessionFactory(store: repository, prompts: []));
    expect(find.text('1 / 2'), findsOneWidget);
    expect(find.byKey(const ValueKey('quiz-answer-feedback')), findsOneWidget);
    expect(find.byKey(const ValueKey('quiz-option-ba')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('quiz-continue')));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(repository.close);

    repository = (await tester.runAsync(open))!;
    addTearDown(repository.close);
    await _pumpReview(
        tester, createTestReviewSessionFactory(store: repository, prompts: []));
    expect(find.text('2 / 2'), findsOneWidget);
    expect(find.textContaining('ㄆ'), findsOneWidget);
    expect((await repository.loadActiveSession())!.prompts.map((p) => p.id),
        ['first', 'second']);
  });

  testWidgets('relaunch keeps a saved recall response visible beside feedback',
      (tester) async {
    final directory = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('bopomofo-recall-resume-')))!;
    addTearDown(() => directory.delete(recursive: true));
    final path = '${directory.path}${Platform.pathSeparator}review.sqlite';
    Future<LocalLearningRepository> open() async {
      final database = LocalDatabase.atPath(path);
      await database.open();
      return LocalLearningRepository(
          database: database, userId: 'recall-resume');
    }

    final prompts = [
      QuizPrompt(
          id: 'recall-ba',
          itemId: 'symbol-ba',
          skill: Skill.production,
          type: QuizType.recall,
          promptKey: 'quiz.recall',
          promptArguments: const {'pinyin': 'ba'},
          expectedAnswer: 'ㄅㄚ',
          options: const ['ㄅㄚ', 'ㄆㄚ']),
      QuizPrompt(
          id: 'recognition-next',
          itemId: 'symbol-next',
          skill: Skill.recognition,
          type: QuizType.recognition,
          promptKey: 'quiz.recognition',
          promptArguments: const {'glyph': 'ㄆ'},
          expectedAnswer: 'pa',
          options: const ['pa', 'ba']),
    ];
    var repository = (await tester.runAsync(open))!;
    await _pumpReview(tester,
        createTestReviewSessionFactory(store: repository, prompts: prompts));
    await tester.enterText(
        find.byKey(const ValueKey('quiz-recall-input')), 'ㄅㄚ');
    await tester.tap(find.byKey(const ValueKey('quiz-submit')));
    await tester.pumpAndSettle();
    final saved = (await repository.loadActiveSession())!;
    expect(saved.currentAnswer?.response, 'ㄅㄚ');
    expect(saved.currentIndex, 0);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(repository.close);

    repository = (await tester.runAsync(open))!;
    addTearDown(repository.close);
    await _pumpReview(
        tester, createTestReviewSessionFactory(store: repository, prompts: []));
    expect(find.text('1 / 2'), findsOneWidget);
    expect(find.text('Enter the Bopomofo for ba.'), findsOneWidget);
    expect(find.text('Correct answer saved locally.'), findsOneWidget);
    expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('quiz-recall-input')))
            .controller!
            .text,
        'ㄅㄚ');
    expect((await repository.loadActiveSession())!.prompts.map((p) => p.id),
        ['recall-ba', 'recognition-next']);
    expect((await repository.loadActiveSession())!.currentIndex, 0);
  });
}

Future<void> _pumpReview(WidgetTester tester, ReviewSessionFactory factory,
    {Locale locale = const Locale('en')}) async {
  await tester.pumpWidget(MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: ReviewPage(sessionFactory: factory)),
  ));
  await tester.pumpAndSettle();
}

QuizSession _sessionWithAudio(String audioId) => QuizSession(
      id: 'saved-audio-session',
      contentVersion: 'starter-v1',
      prompts: [
        testReviewPrompts().first,
        QuizPrompt(
          id: 'queued-audio',
          itemId: 'audio-ba',
          skill: Skill.listening,
          type: QuizType.listening,
          promptKey: 'quiz.listening',
          promptArguments: const {},
          expectedAnswer: 'ㄅㄚ',
          options: const ['ㄆㄚ', 'ㄅㄚ'],
          audioAssetId: audioId,
        ),
      ],
      currentIndex: 0,
      currentQuestionStartedAt: DateTime.utc(2026, 9, 30),
      currentAnswer: null,
      correctCount: 0,
      answeredCount: 0,
      status: QuizSessionStatus.active,
    );
