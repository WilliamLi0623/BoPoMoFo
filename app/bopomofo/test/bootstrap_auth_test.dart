import 'dart:io';

import 'package:auth/auth.dart';
import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:persistence/persistence.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sync/sync.dart' show SyncStatus;

import 'package:bopomofo/bootstrap.dart';

void main() {
  test('missing auth configuration uses an unauthenticated local fallback', () async {
    final dependencies = await AppDependencies.fromConfiguration(
      const AppConfiguration(),
      guestStore: InMemoryGuestIdStore(),
      repositoryFactory: (userId) =>
          LocalLearningRepository.inMemory(userId: userId),
    );

    expect(dependencies.authService, isA<GuestAuthService>());
    expect(dependencies.authService.currentUser, isNotNull);
    expect(
      dependencies.authService.currentUser!.appMetadata['is_guest'],
      isTrue,
    );
    expect((await dependencies.syncService.syncNow()).status, SyncStatus.localOnly);
    await dependencies.repository.close();
  });

  test('invalid Supabase URL keeps the app in guest mode', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    final dependencies = await AppDependencies.fromConfiguration(
      const AppConfiguration(
        supabaseUrl: 'not-a-url',
        supabasePublishableKey: 'test-key',
        googleRedirectUri: 'com.example.app:/oauth',
      ),
      guestStore: InMemoryGuestIdStore(),
      repositoryFactory: (userId) =>
          LocalLearningRepository.inMemory(userId: userId),
    );

    expect(dependencies.authService, isA<GuestAuthService>());
    await dependencies.repository.close();
  });

  test('default bootstrap fallback uses durable preferences storage', () async {
    SharedPreferences.setMockInitialValues({});
    final first = await AppDependencies.fromConfiguration(
      const AppConfiguration(),
      repositoryFactory: (userId) =>
          LocalLearningRepository.inMemory(userId: userId),
    );
    final second = await AppDependencies.fromConfiguration(
      const AppConfiguration(),
      repositoryFactory: (userId) =>
          LocalLearningRepository.inMemory(userId: userId),
    );

    expect(first.authService, isA<GuestAuthService>());
    expect(
      second.authService.currentUser!.id,
      first.authService.currentUser!.id,
    );
  });

  test('application dependencies restore reviews from their persistent store', () async {
    final directory = await Directory.systemTemp.createTemp('bopomofo-bootstrap-');
    final databasePath =
        '${directory.path}${Platform.pathSeparator}learning.sqlite';
    final guestStore = InMemoryGuestIdStore();

    Future<LocalLearningRepository> openRepository(String userId) async {
      final database = LocalDatabase.atPath(databasePath);
      await database.open();
      return LocalLearningRepository(database: database, userId: userId);
    }

    try {
      final first = await AppDependencies.fromConfiguration(
        const AppConfiguration(),
        guestStore: guestStore,
        repositoryFactory: openRepository,
      );
      await first.repository.recordReview(ReviewAttempt(
        itemId: 'ㄅ',
        skill: Skill.keyboard,
        correct: true,
        occurredAt: DateTime.utc(2026, 9, 23),
      ));
      final userId = first.authService.currentUser!.id;
      await first.repository.close();

      final restarted = await AppDependencies.fromConfiguration(
        const AppConfiguration(),
        guestStore: guestStore,
        repositoryFactory: openRepository,
      );

      expect(restarted.authService.currentUser!.id, userId);
      expect((await restarted.repository.snapshot()).reviewStates, hasLength(1));
      await restarted.repository.close();
    } finally {
      await directory.delete(recursive: true);
    }
  });
}
