import 'dart:io';

import 'package:auth/auth.dart';
import 'package:bopomofo/bootstrap.dart';
import 'package:bopomofo/features/review/audio_asset_manifest.dart';
import 'package:bopomofo/features/review/audio_prompt_player.dart';
import 'package:bopomofo/features/review/review_page.dart';
import 'package:bopomofo/l10n/app_localizations.dart';
import 'package:bopomofo/localization/app_locale_controller.dart';
import 'package:bopomofo/localization/locale_preference_store.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:learning_engine/learning_engine.dart';
import 'package:persistence/persistence.dart';
import 'package:phonology/phonology.dart' as phonology;
import 'package:sync/sync.dart';
import '../test/test_support.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('offline five-type session survives app and database restart',
      (tester) async {
    final directory =
        await Directory.systemTemp.createTemp('bopomofo-offline-');
    final databasePath =
        '${directory.path}${Platform.pathSeparator}learning.sqlite';
    final guestStore = InMemoryGuestIdStore();
    final prompts = await _fiveTypeQueue();
    var dependencies = await _dependencies(databasePath, guestStore);
    final firstRepo = dependencies.repository.local;
    final sync = dependencies.syncService as LocalSyncService;
    final firstPlayer = _SilentAudioPromptPlayer();
    final firstFactory = _sessionFactory(firstRepo, prompts, firstPlayer);
    var syncServices = <LocalSyncService>[sync];
    var repositories = <LocalLearningRepository>[firstRepo];

    try {
      await tester.pumpWidget(BopomofoApp(
        dependencies: dependencies,
        localeController: await createEnglishLocaleController(),
        reviewSessionFactory: firstFactory,
      ));
      await _enterReview(tester);
      await _answerCurrent(tester, prompts.first);
      expect(find.byKey(const ValueKey('quiz-answer-feedback')), findsOneWidget);
      expect(find.byKey(const ValueKey('quiz-progress')), findsOneWidget);
      expect((await firstRepo.loadActiveSession())!.currentAnswer!.response,
          prompts.first.expectedAnswer);
      expect((await firstRepo.events.all()), hasLength(1));
      expect((await sync.syncNow()).status, SyncStatus.offline);

      // A new widget tree, dependency graph, repository, database connection,
      // coordinator and silent player simulate an app process restart.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await sync.dispose();
      repositories.remove(firstRepo);
      await firstRepo.close();
      dependencies = await _dependencies(databasePath, guestStore);
      final restartedRepo = dependencies.repository.local;
      repositories.add(restartedRepo);
      final restartedSync = dependencies.syncService as LocalSyncService;
      syncServices.add(restartedSync);
      final restartedPlayer = _SilentAudioPromptPlayer();
      await tester.pumpWidget(BopomofoApp(
        dependencies: dependencies,
        localeController: await createEnglishLocaleController(),
        reviewSessionFactory:
            _sessionFactory(restartedRepo, prompts, restartedPlayer),
      ));
      await _enterReview(tester);
      expect(find.byKey(const ValueKey('quiz-progress')), findsOneWidget);
      expect(find.byKey(const ValueKey('quiz-answer-feedback')), findsOneWidget);
      expect(find.byKey(const ValueKey('quiz-saved-response')), findsOneWidget);
      final progressContext = tester.element(
          find.byKey(const ValueKey('quiz-progress')));
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('quiz-progress'))).data,
        AppLocalizations.of(progressContext)!.quizSessionProgress(1, 5),
      );
      final restored = await restartedRepo.loadActiveSession();
      expect(restored!.currentPrompt!.id, prompts.first.id);
      expect(restored.currentIndex, 0);
      expect(restored.answeredCount, 1);
      expect(restored.correctCount, 1);
      expect(restored.currentAnswer!.response, prompts.first.expectedAnswer);
      expect((await restartedRepo.events.all()), hasLength(1));

      await tester.tap(find.byKey(const ValueKey('quiz-continue')));
      await tester.pumpAndSettle();
      for (final prompt in prompts.skip(1)) {
        expect((await restartedRepo.loadActiveSession())!.currentPrompt!.id,
            prompt.id);
        await _answerCurrent(tester, prompt, player: restartedPlayer);
        expect(find.byKey(const ValueKey('quiz-answer-feedback')), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('quiz-continue')));
        await tester.pumpAndSettle();
      }

      final summaryFinder = find.byKey(const ValueKey('quiz-completion'));
      expect(summaryFinder, findsOneWidget);
      final summaryContext = tester.element(summaryFinder);
      expect(
        tester.widget<Text>(summaryFinder).data,
        AppLocalizations.of(summaryContext)!.quizCompletionSummary(5, 5),
      );
      final completed = await restartedRepo.loadActiveSession();
      expect(completed, isNull);
      final events = await restartedRepo.events.all();
      expect(events, hasLength(5));
      expect(events.every((event) => event.correct), isTrue);
      expect(events.map((event) => event.itemId).toSet(),
          prompts.map((prompt) => prompt.itemId).toSet());
      final history = await restartedRepo.snapshot();
      expect(history.reviewStates, hasLength(5));
      expect(history.reviewStates.every((state) => state.reps == 1), isTrue);
      expect(restartedPlayer.playedIds, [prompts[3].audioAssetId]);
      expect(restartedPlayer.completions, 1);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      for (final service in syncServices) {
        await service.dispose();
      }
      for (final repository in repositories) {
        await repository.close();
      }
      await directory.delete(recursive: true);
    }
  });

  testWidgets('changing language keeps the recorded review in the same repository',
      (tester) async {
    final dependencies = await createTestDependencies();
    final repository = dependencies.repository;
    final local = repository.local;
    final sync = dependencies.syncService as LocalSyncService;
    final localeStore = _MemoryLocalePreferenceStore('en');
    final localeController = await AppLocaleController.load(
      store: localeStore,
      platformLocales: const [Locale('en')],
    );
    addTearDown(() async {
      await sync.dispose();
      await repository.close();
    });

    final app = BopomofoApp(
      dependencies: dependencies,
      localeController: localeController,
    );
    await tester.pumpWidget(app);
    await tester.tap(find.byKey(const ValueKey('path-sounds')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Review due items'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('review-answer-correct')));
    await tester.pumpAndSettle();
    expect(find.text('Saved locally'), findsOneWidget);
    expect((await repository.snapshot()).reviewStates.single.reps, 1);
    expect((await local.pendingEvents()), hasLength(1));

    await tester.tap(find.byKey(const ValueKey('nav-settings')));
    await tester.pumpAndSettle();
    expect(find.text('Language'), findsOneWidget);

    for (final selection in [
      (
        option: '简体中文',
        language: '语言',
        saved: '进度已保存在本机。',
        tag: 'zh-Hans',
      ),
      (
        option: '繁體中文',
        language: '語言',
        saved: '進度已儲存在本機。',
        tag: 'zh-Hant',
      ),
      (
        option: 'English',
        language: 'Language',
        saved: 'Progress is saved locally.',
        tag: 'en',
      ),
    ]) {
      await tester.tap(find.byKey(const ValueKey('settings-language')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(selection.option).last);
      await tester.pumpAndSettle();

      expect(localeStore.localeTag, selection.tag);
      expect(find.text(selection.language), findsOneWidget);
      expect(find.text(selection.saved), findsOneWidget);
      final mountedApp = tester.widget<BopomofoApp>(find.byType(BopomofoApp));
      expect(identical(mountedApp, app), isTrue);
      expect(identical(mountedApp.dependencies.repository, repository), isTrue);
      expect(identical(repository.local, local), isTrue);
      expect((await repository.snapshot()).reviewStates.single.reps, 1);
      expect((await local.pendingEvents()), hasLength(1));
    }
  });
}

Future<List<QuizPrompt>> _fiveTypeQueue() async {
  final manifest = await AudioAssetManifest.load(rootBundle);
  final entry = manifest.entries.first;
  final bytes = await rootBundle.load(entry.assetPath);
  expect(bytes.lengthInBytes, greaterThan(0));
  expect(manifest.assetPathForId(entry.id), entry.assetPath);
  final symbol = phonology.symbols.firstWhere((item) => item.pinyin == 'b');
  final syllable = entry.expectedAnswer;
  final syllableGlyphs = syllable.runes.map(String.fromCharCode).toList();
  expect(manifest.assetPathForId(entry.id), startsWith('assets/audio/'));
  final prompts = <QuizPrompt>[
    QuizPrompt(
      id: 'offline-recognition',
      itemId: 'offline-recognition-item',
      skill: Skill.recognition,
      type: QuizType.recognition,
      promptKey: 'quiz.recognition',
      promptArguments: {'glyph': symbol.glyph},
      expectedAnswer: symbol.pinyin!,
      options: [symbol.pinyin!, 'p'],
    ),
    QuizPrompt(
      id: 'offline-recall',
      itemId: 'offline-recall-item',
      skill: Skill.production,
      type: QuizType.recall,
      promptKey: 'quiz.recall',
      promptArguments: {'pinyin': symbol.pinyin!},
      expectedAnswer: symbol.glyph,
      options: [symbol.glyph, 'ㄆ'],
    ),
    QuizPrompt(
      id: 'offline-composition',
      itemId: 'offline-composition-item',
      skill: Skill.composition,
      type: QuizType.composition,
      promptKey: 'quiz.composition',
      promptArguments: {'pinyin': 'ba'},
      expectedAnswer: syllable,
      options: [...syllableGlyphs, 'ㄇ'],
    ),
    QuizPrompt(
      id: 'offline-listening',
      itemId: 'offline-listening-item',
      skill: Skill.listening,
      type: QuizType.listening,
      promptKey: 'quiz.listening',
      promptArguments: const {},
      expectedAnswer: syllable,
      options: [syllable, 'ㄇㄚ'],
      audioAssetId: entry.id,
    ),
    QuizPrompt(
      id: 'offline-keyboard',
      itemId: 'offline-keyboard-item',
      skill: Skill.keyboard,
      type: QuizType.keyboard,
      promptKey: 'quiz.keyboard',
      promptArguments: {'pinyin': symbol.pinyin!},
      expectedAnswer: symbol.glyph,
      options: [symbol.glyph, 'ㄆ'],
    ),
  ];
  expect(prompts.map((prompt) => prompt.type).toSet(), QuizType.values.toSet());
  return prompts;
}

Future<AppDependencies> _dependencies(
        String databasePath, GuestIdStore guestStore) =>
    AppDependencies.fromConfiguration(
      const AppConfiguration(),
      guestStore: guestStore,
      repositoryFactory: (userId) async {
        final database = LocalDatabase.atPath(databasePath);
        await database.open();
        return LocalLearningRepository(
          database: database,
          userId: userId,
          deviceId: 'offline-device',
        );
      },
    );

ReviewSessionFactory _sessionFactory(
  LocalLearningRepository repository,
  List<QuizPrompt> prompts,
  _SilentAudioPromptPlayer player,
) =>
    () async => ReviewSessionRuntime(
          coordinator: QuizSessionCoordinator(
            store: repository,
            queueFactory: () async => prompts,
            newSessionId: () => 'offline-five-type-session',
            now: () => DateTime.utc(2026),
            contentVersion: 'starter-v1',
          ),
          audioPlayer: player,
        );

Future<void> _enterReview(WidgetTester tester) async {
  if (find.byKey(const ValueKey('path-sounds')).evaluate().isNotEmpty) {
    await tester.tap(find.byKey(const ValueKey('path-sounds')));
    await tester.pumpAndSettle();
  }
  if (find.text('Review due items').evaluate().isNotEmpty) {
    await tester.tap(find.text('Review due items'));
    await tester.pumpAndSettle();
  }
}

Future<void> _answerCurrent(
  WidgetTester tester,
  QuizPrompt prompt, {
  _SilentAudioPromptPlayer? player,
}) async {
  switch (prompt.type) {
    case QuizType.recognition:
      await tester.tap(find.byKey(ValueKey('quiz-option-${prompt.expectedAnswer}')));
    case QuizType.recall:
      await tester.enterText(
          find.byKey(const ValueKey('quiz-recall-input')), prompt.expectedAnswer);
      await tester.tap(find.byKey(const ValueKey('quiz-submit')));
    case QuizType.composition:
      for (final glyph in prompt.expectedAnswer.runes.map(String.fromCharCode)) {
        await tester.tap(find.byKey(ValueKey('quiz-tile-$glyph')));
      }
      await tester.tap(find.byKey(const ValueKey('quiz-submit')));
    case QuizType.listening:
      final assetId = prompt.audioAssetId!;
      await tester.tap(find.byKey(const ValueKey('quiz-play-audio')));
      await tester.pumpAndSettle();
      expect(player!.playedIds, contains(assetId));
      expect(player.completions, 1);
      expect(tester.widget<FilledButton>(
              find.byKey(const ValueKey('quiz-play-audio'))).onPressed,
          isNotNull);
      await tester.tap(find.byKey(ValueKey('quiz-option-${prompt.expectedAnswer}')));
    case QuizType.keyboard:
      final mapping = phonology.symbols.firstWhere(
          (symbol) => symbol.glyph == prompt.expectedAnswer);
      await tester.tap(find.byKey(ValueKey('quiz-key-${mapping.keyboardKey}')));
  }
  await tester.pumpAndSettle();
}

class _SilentAudioPromptPlayer implements AudioPromptPlayer {
  final playedIds = <String>[];
  int completions = 0;

  @override
  Future<void> play(String assetId) async {
    playedIds.add(assetId);
    await Future<void>.value();
    completions++;
  }

  @override
  Future<void> dispose() async {}
}

class _MemoryLocalePreferenceStore implements LocalePreferenceStore {
  _MemoryLocalePreferenceStore(this.localeTag);

  String? localeTag;

  @override
  Future<String?> readLocaleTag() async => localeTag;

  @override
  Future<void> writeLocaleTag(String tag) async {
    localeTag = tag;
  }
}
