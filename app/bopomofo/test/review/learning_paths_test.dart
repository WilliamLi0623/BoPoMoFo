import 'package:bopomofo/features/lesson/learning_path.dart';
import 'package:bopomofo/features/lesson/lesson_page.dart';
import 'package:bopomofo/features/review/audio_asset_manifest.dart';
import 'package:bopomofo/features/review/audio_prompt_player.dart';
import 'package:bopomofo/l10n/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_engine/learning_engine.dart';
import 'package:material_ui/material_ui.dart';
import 'package:persistence/persistence.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('learning routes offer distinct, answerable exercises', () async {
    final manifest = await AudioAssetManifest.load(rootBundle);
    final pinyin = starterPromptsForPath(LearningPath.pinyin, manifest);
    final sounds = starterPromptsForPath(LearningPath.sounds, manifest);
    final beginner = starterPromptsForPath(LearningPath.beginner, manifest);

    expect(pinyin, isNotEmpty);
    expect(pinyin.every((quiz) => quiz.promptArguments.containsKey('pinyin')),
        isTrue);
    expect(sounds.map((quiz) => quiz.expectedAnswer), ['ㄅㄚ', 'ㄇㄚ']);
    expect(sounds.every((quiz) => quiz.type == QuizType.listening), isTrue);
    expect(beginner.map((quiz) => quiz.expectedAnswer), ['ㄅ', 'ㄆ', 'ㄇ', 'ㄈ']);
    expect(
        beginner.every((quiz) => !quiz.promptArguments.containsKey('pinyin')),
        isTrue);
  });

  test('unfinished route and mixed reviews keep separate local sessions',
      () async {
    final repo = await LocalLearningRepository.inMemory();
    addTearDown(repo.close);
    final manifest = await AudioAssetManifest.load(rootBundle);
    QuizSession session(String id, LearningPath path) => QuizSession(
          id: id,
          contentVersion: 'starter-v1',
          prompts: starterPromptsForPath(path, manifest).take(1).toList(),
          currentIndex: 0,
          currentQuestionStartedAt: DateTime.utc(2026),
          currentAnswer: null,
          correctCount: 0,
          answeredCount: 0,
          status: QuizSessionStatus.active,
        );
    await repo.saveNewSession(session('mixed', LearningPath.pinyin));
    final sounds = repo.quizSessions(LearningPath.sounds.name);
    final beginner = repo.quizSessions(LearningPath.beginner.name);
    await sounds.saveNewSession(session('listen', LearningPath.sounds));
    await beginner.saveNewSession(session('begin', LearningPath.beginner));
    await beginner.submitAnswer(
      sessionId: 'begin',
      expectedIndex: 0,
      response: 'ㄅ',
      correct: true,
      occurredAt: DateTime.utc(2026),
      latencyMs: 100,
    );
    expect((await beginner.loadActiveSession())?.currentAnswer?.response, 'ㄅ');
    expect((await sounds.loadActiveSession())?.currentAnswer, isNull);
    expect((await repo.loadActiveSession())?.id, 'mixed');
    expect(await repo.events.all(), hasLength(1));
  });

  testWidgets('listen-first lesson directly plays both bundled recordings',
      (tester) async {
    final output = _RecordingOutput();
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
          body: LessonPage(
        path: LearningPath.sounds,
        onPractice: (_) async => null,
        onReview: () {},
        audioOutput: output,
      )),
    ));
    await tester.runAsync(() async {
      await tester.pumpAndSettle();
    });
    final ba = find.byKey(const ValueKey('lesson-audio-cns11643-female-ba'));
    final ma = find.byKey(const ValueKey('lesson-audio-cns11643-female-ma'));
    await tester.tap(ba);
    await tester.pumpAndSettle();
    await tester.tap(ma);
    await tester.pumpAndSettle();
    expect(output.paths, ['audio/F_ba.mp3', 'audio/F_ma.mp3']);
  });
}

class _RecordingOutput implements AudioPromptAudioOutput {
  final paths = <String>[];
  @override
  Future<void> playAsset(String assetPath) async => paths.add(assetPath);
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {}
}
