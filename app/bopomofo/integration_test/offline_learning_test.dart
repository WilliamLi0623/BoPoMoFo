import 'dart:io';

import 'package:auth/auth.dart';
import 'package:bopomofo/bootstrap.dart';
import 'package:bopomofo/localization/app_locale_controller.dart';
import 'package:bopomofo/localization/locale_preference_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:persistence/persistence.dart';
import 'package:sync/sync.dart';
import '../test/test_support.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'guest completes onboarding and review offline, then restores progress',
      (tester) async {
    final directory =
        await Directory.systemTemp.createTemp('bopomofo-offline-');
    final databasePath =
        '${directory.path}${Platform.pathSeparator}learning.sqlite';
    final dependencies = await AppDependencies.fromConfiguration(
      const AppConfiguration(),
      guestStore: InMemoryGuestIdStore(),
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
    final repository = dependencies.repository;
    final local = repository.local;
    final sync = dependencies.syncService as LocalSyncService;
    var repositoryClosed = false;

    try {
      await tester.pumpWidget(BopomofoApp(
        dependencies: dependencies,
        localeController: await createEnglishLocaleController(),
      ));
      expect(find.text('Guest mode · saved locally'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('path-sounds')));
      await tester.pumpAndSettle();
      expect(find.text('Your first lesson'), findsOneWidget);

      await tester.tap(find.text('Review due items'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('review-answer-correct')));
      await tester.pumpAndSettle();
      expect(find.text('Saved locally'), findsOneWidget);

      final syncResult = await sync.syncNow();
      expect(syncResult.status, SyncStatus.offline);
      expect((await local.pendingEvents()).length, 1);

      await repository.close();
      repositoryClosed = true;
      final restartedDatabase = LocalDatabase.atPath(databasePath);
      await restartedDatabase.open();
      final restarted = LocalLearningRepository(
        database: restartedDatabase,
        userId: dependencies.authService.currentUser!.id,
        deviceId: 'offline-device',
      );
      final restored = await restarted.snapshot();
      expect(restored.reviewStates, hasLength(1));
      expect(restored.reviewStates.single.reps, 1);
      expect(restored.reviewStates.single.stability, greaterThan(1));
      expect((await restarted.events.all()).single.eventId,
          startsWith('offline-device-'));
      await restarted.close();
    } finally {
      await sync.dispose();
      if (!repositoryClosed) await repository.close();
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
