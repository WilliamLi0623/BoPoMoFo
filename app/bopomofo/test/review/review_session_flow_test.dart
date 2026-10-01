import 'dart:io';

import 'package:bopomofo/features/review/review_page.dart';
import 'package:bopomofo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:domain/domain.dart';
import 'package:learning_engine/learning_engine.dart';
import 'package:persistence/persistence.dart';

import '../test_support.dart';

void main() {
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

Future<void> _pumpReview(
    WidgetTester tester, ReviewSessionFactory factory) async {
  await tester.pumpWidget(MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: ReviewPage(sessionFactory: factory)),
  ));
  await tester.pumpAndSettle();
}
