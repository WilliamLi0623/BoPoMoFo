import 'dart:async';
import 'dart:io';
import 'dart:ui' show PlatformDispatcher;
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:domain/domain.dart';
import 'package:auth/auth.dart';
import 'package:persistence/persistence.dart';
import 'package:learning_engine/learning_engine.dart'
    show
        LearningSnapshot,
        QuizPrompt,
        QuizSession,
        QuizSessionStore,
        QuizSessionCoordinator,
        nextPrompts;
import 'package:sync/sync.dart' as sync;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show OAuthProvider, SupabaseClient;

import 'app.dart';
import 'features/lesson/learning_path.dart';
import 'features/review/audio_asset_manifest.dart';
import 'features/review/audio_prompt_player.dart';
import 'features/review/review_page.dart';
import 'features/review/starter_question_bank.dart';
import 'localization/app_locale_controller.dart';
import 'localization/locale_preference_store.dart';
import 'localization/shared_preferences_locale_preference_store.dart';

export 'app.dart' show BopomofoApp;

typedef SyncService = sync.SyncService;
typedef LocalRepositoryFactory = Future<LocalLearningRepository> Function(
    String userId);

class AppLearningRepository implements LearningRepository, QuizSessionStore {
  AppLearningRepository(this.local) : _dashboard = const DashboardSnapshot();

  final LocalLearningRepository local;
  DashboardSnapshot _dashboard;
  final StreamController<DashboardSnapshot> _updates =
      StreamController.broadcast();
  LearningSnapshot _snapshot = const LearningSnapshot();

  DashboardSnapshot get dashboard => _dashboard;

  double masteryFor(Skill skill) {
    final states =
        _snapshot.reviewStates.where((state) => state.skill == skill);
    final stability = states.fold<double>(
        0, (max, state) => state.stability > max ? state.stability : max);
    return (stability / 21).clamp(0, 1).toDouble();
  }

  @override
  Future<void> recordReview(ReviewAttempt attempt) async {
    await local.recordReview(attempt);
    await _refresh();
  }

  Future<String> exportLearningData() => local.exportLearningData();

  Future<void> importLearningData(String source) async {
    await local.importLearningData(source);
    await _refresh();
  }

  Future<LearningSnapshot> snapshot() => local.snapshot();

  @override
  Future<QuizSession?> loadActiveSession({
    bool Function(QuizPrompt)? isPromptAvailable,
  }) =>
      local.loadActiveSession(isPromptAvailable: isPromptAvailable);

  @override
  Future<void> saveNewSession(QuizSession session) =>
      local.saveNewSession(session);

  @override
  Future<QuizSession> submitAnswer({
    required String sessionId,
    required int expectedIndex,
    required String response,
    required bool correct,
    required DateTime occurredAt,
    required int latencyMs,
  }) async {
    final result = await local.submitAnswer(
      sessionId: sessionId,
      expectedIndex: expectedIndex,
      response: response,
      correct: correct,
      occurredAt: occurredAt,
      latencyMs: latencyMs,
    );
    await _refresh();
    return result;
  }

  @override
  Future<QuizSession> continueSession({
    required String sessionId,
    required int expectedIndex,
  }) =>
      local.continueSession(sessionId: sessionId, expectedIndex: expectedIndex);

  @override
  Stream<DashboardSnapshot> watchDashboard() async* {
    await _refresh();
    yield _dashboard;
    yield* _updates.stream;
  }

  Future<void> _refresh() async {
    _snapshot = await local.snapshot();
    final now = DateTime.now().toUtc();
    _dashboard = DashboardSnapshot(
      dueCount: _snapshot.reviewStates
          .where((state) => !state.dueAt.isAfter(now))
          .length,
      masteredCount:
          _snapshot.reviewStates.where((state) => state.stability >= 21).length,
    );
    _updates.add(_dashboard);
  }

  Future<void> close() async {
    await _updates.close();
    await local.close();
  }
}

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  LocalePreferenceStore localeStore;
  try {
    localeStore = SharedPreferencesLocalePreferenceStore(
      await SharedPreferences.getInstance(),
    );
  } on Object {
    localeStore = const _UnavailableLocalePreferenceStore();
  }
  final localeController = await AppLocaleController.load(
    store: localeStore,
    platformLocales: PlatformDispatcher.instance.locales,
  );
  final dependencies = await AppDependencies.fromConfiguration(
    AppConfiguration.fromEnvironment(),
  );

  runApp(BopomofoApp(
    dependencies: dependencies,
    localeController: localeController,
  ));
}

class _UnavailableLocalePreferenceStore implements LocalePreferenceStore {
  const _UnavailableLocalePreferenceStore();

  @override
  Future<String?> readLocaleTag() async => null;

  @override
  Future<void> writeLocaleTag(String localeTag) async =>
      throw StateError('Locale preferences unavailable');
}

class AppConfiguration {
  const AppConfiguration({
    this.supabaseUrl,
    this.supabasePublishableKey,
    this.googleRedirectUri,
    this.googleWebClientId,
    this.appleRedirectUri,
  });

  final String? supabaseUrl;
  final String? supabasePublishableKey;
  final String? googleRedirectUri;
  final String? googleWebClientId;
  final String? appleRedirectUri;

  factory AppConfiguration.fromEnvironment() => const AppConfiguration(
        supabaseUrl: String.fromEnvironment('SUPABASE_URL'),
        supabasePublishableKey: String.fromEnvironment(
          'SUPABASE_PUBLISHABLE_KEY',
        ),
        googleRedirectUri: String.fromEnvironment('GOOGLE_OAUTH_REDIRECT_URI'),
        googleWebClientId: String.fromEnvironment('GOOGLE_OAUTH_CLIENT_ID'),
        appleRedirectUri: String.fromEnvironment('APPLE_REDIRECT_URI'),
      );

  Map<String, String> get authEnvironment => {
        if (supabaseUrl != null) 'SUPABASE_URL': supabaseUrl!,
        if (supabasePublishableKey != null)
          'SUPABASE_PUBLISHABLE_KEY': supabasePublishableKey!,
        if (googleRedirectUri != null)
          'GOOGLE_OAUTH_REDIRECT_URI': googleRedirectUri!,
        if (appleRedirectUri != null) 'APPLE_REDIRECT_URI': appleRedirectUri!,
      };
}

class LearningEngine {
  const LearningEngine(this.localDatabase);

  final AppLearningRepository localDatabase;
}

class AppDependencies {
  const AppDependencies({
    required this.configuration,
    required this.authService,
    required this.syncService,
    required this.learningEngine,
    required this.repository,
  });

  final AppConfiguration configuration;
  final AuthService authService;
  final SyncService syncService;
  final LearningEngine learningEngine;
  final AppLearningRepository repository;

  Future<ReviewSessionRuntime> createReviewSessionRuntime({
    LearningPath? path,
  }) async {
    final manifest = await AudioAssetManifest.loadBundled(rootBundle);
    final prompts = path == null
        ? buildStarterQuestionBank(manifest)
        : starterPromptsForPath(path, manifest);
    return ReviewSessionRuntime(
      coordinator: QuizSessionCoordinator(
        store: path == null
            ? repository
            : repository.local.quizSessions(path.name),
        queueFactory: () async => nextPrompts(
          await repository.snapshot(),
          DateTime.now().toUtc(),
          10,
          starterPrompts: prompts,
        ),
        newSessionId: () =>
            DateTime.now().toUtc().microsecondsSinceEpoch.toString(),
        now: () => DateTime.now().toUtc(),
        contentVersion: 'starter-v1',
        isPromptAvailable: (prompt) =>
            prompt.audioAssetId == null ||
            manifest.assetPathForId(prompt.audioAssetId!) != null,
      ),
      audioPlayer: OfflineAudioPromptPlayer(manifest: manifest),
    );
  }

  static Future<AppDependencies> fromConfiguration(
    AppConfiguration configuration, {
    GuestIdStore? guestStore,
    LocalRepositoryFactory? repositoryFactory,
  }) async {
    final auth = await _authService(
      configuration,
      guestStore: guestStore,
    );
    final userId = auth.service.currentUser?.id ?? 'local-user';
    final localRepository = repositoryFactory == null
        ? await _openPersistentRepository(userId)
        : await repositoryFactory(userId);
    final repository = AppLearningRepository(localRepository);
    final client = auth.client;
    final syncService = sync.LocalSyncService(
      repository: repository.local,
      cursorKey: sync.SupabaseSyncTransport.cursorKey,
      resolveTransport: client == null
          ? null
          : () => sync.SupabaseSyncTransport.forRepository(client, localRepository),
    );
    final learningEngine = LearningEngine(repository);

    return AppDependencies(
      configuration: configuration,
      authService: auth.service,
      syncService: syncService,
      learningEngine: learningEngine,
      repository: repository,
    );
  }

  static Future<LocalLearningRepository> _openPersistentRepository(
    String userId,
  ) async {
    final directory = await getApplicationSupportDirectory();
    await directory.create(recursive: true);
    final path = '${directory.path}${Platform.pathSeparator}bopomofo.sqlite';
    final database = LocalDatabase.atPath(path);
    await database.open();
    return LocalLearningRepository(database: database, userId: userId);
  }

  static Future<({AuthService service, SupabaseClient? client})> _authService(
    AppConfiguration configuration, {
    GuestIdStore? guestStore,
  }) async {
    try {
      final authConfiguration = AuthConfiguration.fromEnvironment(
        configuration.authEnvironment,
      );
      final gateway = await SupabaseAuthGateway.initialize(authConfiguration);
      final nativeGoogle = Platform.isAndroid
          ? NativeGoogleSignIn(
              serverClientId: configuration.googleWebClientId ?? '',
              exchangeIdToken: ({required idToken, required nonce}) async {
                final response = await gateway.client.auth.signInWithIdToken(
                  provider: OAuthProvider.google,
                  idToken: idToken,
                  nonce: nonce,
                );
                return response.session?.user;
              },
            )
          : null;
      final service = SupabaseAuthService(
        configuration: authConfiguration,
        gateway: gateway,
        nativeGoogleSignIn: nativeGoogle?.signIn,
      );
      return (service: service, client: gateway.client);
    } on AuthConfigurationError {
      return (service: await _guestAuthService(guestStore), client: null);
    } on Exception {
      return (service: await _guestAuthService(guestStore), client: null);
    }
  }

  static Future<AuthService> _guestAuthService(GuestIdStore? guestStore) {
    if (guestStore != null) {
      return GuestAuthService.create(store: guestStore);
    }
    return GuestAuthService.createPersistent();
  }
}
