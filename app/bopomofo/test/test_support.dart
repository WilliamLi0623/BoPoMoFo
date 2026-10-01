import 'package:auth/auth.dart';
import 'package:bopomofo/bootstrap.dart';
import 'package:persistence/persistence.dart';
import 'package:bopomofo/localization/app_locale_controller.dart';
import 'package:bopomofo/localization/locale_preference_store.dart';
import 'package:flutter/widgets.dart';
import 'package:bopomofo/features/review/review_page.dart';
import 'package:bopomofo/features/review/audio_prompt_player.dart';
import 'package:bopomofo/features/review/audio_asset_manifest.dart';
import 'package:domain/domain.dart';
import 'package:learning_engine/learning_engine.dart';

Future<AppLocaleController> createEnglishLocaleController() =>
    AppLocaleController.load(
      store: _EnglishPreferenceStore(),
      platformLocales: const [Locale('zh', 'TW')],
    );

class _EnglishPreferenceStore implements LocalePreferenceStore {
  @override
  Future<String?> readLocaleTag() async => 'en';

  @override
  Future<void> writeLocaleTag(String tag) async {}
}

Future<AppDependencies> createTestDependencies({
  AppConfiguration configuration = const AppConfiguration(),
  GuestIdStore? guestStore,
  LocalRepositoryFactory? repositoryFactory,
}) =>
    AppDependencies.fromConfiguration(
      configuration,
      guestStore: guestStore ?? InMemoryGuestIdStore(),
      repositoryFactory: repositoryFactory ??
          (userId) => LocalLearningRepository.inMemory(userId: userId),
    );

class FakeAudioPromptPlayer implements AudioPromptPlayer {
  @override
  Future<void> play(String assetId) async {}

  @override
  Future<void> dispose() async {}
}

List<QuizPrompt> testReviewPrompts() => [
      QuizPrompt(
          id: 'first',
          itemId: 'symbol-b',
          skill: Skill.recognition,
          type: QuizType.recognition,
          promptKey: 'quiz.recognition',
          promptArguments: const {'glyph': 'ㄅ'},
          expectedAnswer: 'ba',
          options: const ['ba', 'pa']),
      QuizPrompt(
          id: 'second',
          itemId: 'symbol-p',
          skill: Skill.recognition,
          type: QuizType.recognition,
          promptKey: 'quiz.recognition',
          promptArguments: const {'glyph': 'ㄆ'},
          expectedAnswer: 'pa',
          options: const ['pa', 'ba']),
    ];

ReviewSessionFactory createTestReviewSessionFactory({
  required QuizSessionStore store,
  List<QuizPrompt>? prompts,
  AudioAssetManifest? manifest,
}) =>
    () async => ReviewSessionRuntime(
          coordinator: QuizSessionCoordinator(
            store: store,
            queueFactory: () async => prompts ?? testReviewPrompts(),
            newSessionId: () =>
                DateTime.now().microsecondsSinceEpoch.toString(),
            now: () => DateTime.now().toUtc(),
            contentVersion: 'starter-v1',
            isPromptAvailable: manifest == null
                ? null
                : (prompt) =>
                    prompt.audioAssetId == null ||
                    manifest.assetPathForId(prompt.audioAssetId!) != null,
          ),
          audioPlayer: FakeAudioPromptPlayer(),
        );
