import 'dart:io';

import 'package:auth/auth.dart';
import 'package:bopomofo/bootstrap.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:persistence/persistence.dart';
import 'package:sync/sync.dart';

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
      await tester.pumpWidget(BopomofoApp(dependencies: dependencies));
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
}
