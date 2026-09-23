import 'package:auth/auth.dart';
import 'package:bopomofo/bootstrap.dart';
import 'package:persistence/persistence.dart';

Future<AppDependencies> createTestDependencies({
  AppConfiguration configuration = const AppConfiguration(),
  GuestIdStore? guestStore,
}) =>
    AppDependencies.fromConfiguration(
      configuration,
      guestStore: guestStore ?? InMemoryGuestIdStore(),
      repositoryFactory: (userId) =>
          LocalLearningRepository.inMemory(userId: userId),
    );
