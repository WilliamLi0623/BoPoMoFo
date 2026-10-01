import 'package:auth/auth.dart';
import 'package:bopomofo/bootstrap.dart';
import 'package:persistence/persistence.dart';
import 'package:bopomofo/localization/app_locale_controller.dart';
import 'package:bopomofo/localization/locale_preference_store.dart';
import 'package:flutter/widgets.dart';

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
