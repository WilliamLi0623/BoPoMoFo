import 'dart:convert';

import 'package:bopomofo/features/lesson/learning_path.dart';
import 'package:bopomofo/features/lesson/lesson_page.dart';
import 'package:bopomofo/features/review/audio_asset_manifest.dart';
import 'package:bopomofo/l10n/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_engine/learning_engine.dart';
import 'package:material_ui/material_ui.dart';
import 'package:persistence/persistence.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('each route has three distinct lesson scopes and real exercises',
      () async {
    final manifest = await AudioAssetManifest.loadBundled(rootBundle);
    final allScopes = <String>{};
    for (final path in LearningPath.values) {
      final lessons = lessonsForPath(path);
      expect(lessons.map((lesson) => lesson.number).toList(),
          [for (var number = 1; number <= lessons.length; number++) number]);
      expect(lessons.length, greaterThanOrEqualTo(3));
      expect(lessons.first.scope, path.name,
          reason: 'Preserve previous practice');
      for (final lesson in lessons) {
        expect(allScopes.add(lesson.scope), isTrue);
        final questions = starterPromptsForLesson(lesson, manifest);
        expect(questions.length, greaterThanOrEqualTo(2));
        // Symbol-level prompts intentionally reappear across the lessons of
        // one route as spaced rehearsal; uniqueness is per lesson session.
        final ids = <String>{};
        for (final question in questions) {
          expect(ids.add(question.id), isTrue,
              reason: 'duplicate question id inside ${lesson.scope}');
          expect(question.evaluate(question.expectedAnswer), isTrue);
        }
        if (path == LearningPath.sounds) {
          expect(questions, hasLength(2));
          for (final question in questions) {
            expect(question.type, QuizType.listening);
            final asset = manifest.assetPathForId(question.audioAssetId!)!;
            expect((await rootBundle.load(asset)).lengthInBytes,
                greaterThan(1000));
          }
        }
      }
    }
    final finals = starterPromptsForLesson(
        lessonsForPath(LearningPath.beginner)[1], manifest);
    expect(finals.map((question) => question.expectedAnswer),
        ['ㄚ', 'ㄛ', 'ㄧ', 'ㄨ']);
  });

  test('earlier completions are recognized and remain after repeating a lesson',
      () async {
    final repo = await LocalLearningRepository.inMemory();
    addTearDown(repo.close);
    final manifest = await AudioAssetManifest.loadBundled(rootBundle);
    final lessons = lessonsForPath(LearningPath.beginner);
    final activity = lessons.first;
    final prompt = starterPromptsForLesson(activity, manifest).first;
    final now = DateTime.utc(2026, 11, 20);
    QuizSession session(String id) => QuizSession(
          id: id,
          contentVersion: 'starter-v1',
          prompts: [prompt],
          currentIndex: 0,
          currentQuestionStartedAt: now,
          currentAnswer: null,
          answeredCount: 0,
          correctCount: 0,
          status: QuizSessionStatus.active,
        );
    final legacyCompletion = session('previous-version').copyWith(
      currentIndex: 1,
      answeredCount: 1,
      correctCount: 1,
      status: QuizSessionStatus.completed,
    );
    await repo.database.execute(
      'INSERT INTO settings (key, value) VALUES (?, ?)',
      ['quiz.activeSession.beginner', jsonEncode(legacyCompletion.toJson())],
    );
    final scopes = lessons.map((lesson) => lesson.scope);
    expect(await repo.completedQuizScopes(scopes), {activity.scope});
    final store = repo.quizSessions(activity.scope);
    await store.saveNewSession(session('repeat'));
    expect(await repo.completedQuizScopes(scopes), {activity.scope});
    await store.submitAnswer(
        sessionId: 'repeat',
        expectedIndex: 0,
        response: prompt.expectedAnswer,
        correct: true,
        occurredAt: now,
        latencyMs: 50);
    await store.continueSession(sessionId: 'repeat', expectedIndex: 0);
    await store.saveNewSession(session('third-attempt'));
    expect(await repo.completedQuizScopes(scopes), {activity.scope});
    expect(
        await repo.quizSessions(lessons[1].scope).loadActiveSession(), isNull);
  });

  testWidgets('course resumes first incomplete lesson and moves forward',
      (tester) async {
    final activities = lessonsForPath(LearningPath.pinyin);
    final completed = {activities.first.scope};
    final practiced = <String>[];
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
          body: LessonPage(
        path: LearningPath.pinyin,
        loadCompleted: () async => {...completed},
        onPractice: (lesson) async {
          practiced.add(lesson.scope);
          completed.add(lesson.scope);
          return true;
        },
        onReview: () {},
      )),
    ));
    await tester.pumpAndSettle();
    expect(find.text('bo → ㄅㄛ'), findsOneWidget);
    await tester.ensureVisible(
        find.byKey(const ValueKey('lesson-start-path-practice')));
    await tester.tap(find.byKey(const ValueKey('lesson-start-path-practice')));
    await tester.pumpAndSettle();
    expect(practiced, [activities[1].scope]);
    expect(find.text('na → ㄋㄚ'), findsOneWidget);
    final first = find.byKey(const ValueKey('course-lesson-1'));
    await tester.ensureVisible(first);
    await tester.tap(first);
    await tester.pumpAndSettle();
    expect(find.text('ba → ㄅㄚ'), findsOneWidget);
  });
}
