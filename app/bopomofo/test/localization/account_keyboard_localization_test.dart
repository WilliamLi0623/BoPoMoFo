import 'dart:async';

import 'package:auth/auth.dart';
import 'package:bopomofo/bootstrap.dart';
import 'package:bopomofo/localization/app_locale_controller.dart';
import 'package:bopomofo/localization/locale_preference_store.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sync/sync.dart' show SyncResult, SyncState, SyncStatus;

import '../test_support.dart';

class _LocaleStore implements LocalePreferenceStore {
  const _LocaleStore(this.tag);

  final String tag;

  @override
  Future<String?> readLocaleTag() async => tag;

  @override
  Future<void> writeLocaleTag(String tag) async {}
}

class _FailingDeleteAuth implements AuthService {
  const _FailingDeleteAuth(this.delegate);

  final AuthService delegate;

  @override
  Stream<AuthState> get authStateChanges => delegate.authStateChanges;

  @override
  User? get currentUser => delegate.currentUser;

  @override
  Future<User?> signInWithGoogle() => delegate.signInWithGoogle();

  @override
  Future<User?> signInWithApple() => delegate.signInWithApple();

  @override
  Future<void> signOut() => delegate.signOut();

  @override
  Future<void> deleteAccount() => Future<void>.error(StateError('private deletion detail'));
}

class _ReturningSignInAuth implements AuthService {
  const _ReturningSignInAuth(this.delegate, this.result);

  final AuthService delegate;
  final User? result;

  @override
  Stream<AuthState> get authStateChanges => delegate.authStateChanges;

  @override
  User? get currentUser => delegate.currentUser;

  @override
  Future<User?> signInWithGoogle() async => result;

  @override
  Future<User?> signInWithApple() => delegate.signInWithApple();

  @override
  Future<void> signOut() => delegate.signOut();

  @override
  Future<void> deleteAccount() => delegate.deleteAccount();
}

class _ResultSyncService implements SyncService {
  const _ResultSyncService(this.result);

  final SyncResult result;

  @override
  Stream<SyncState> get state => const Stream<SyncState>.empty();

  @override
  Future<SyncResult> syncNow() async => result;

  @override
  Future<void> scheduleBackgroundSync() async {}
}

Future<AppLocaleController> _locale(String tag) => AppLocaleController.load(
      store: _LocaleStore(tag),
      platformLocales: const [Locale('en')],
    );

void main() {
  for (final localized in [
    (tag: 'en', signIn: 'Sign in with Google', started: 'Google sign-in started. Complete sign-in to continue.'),
    (tag: 'zh-Hans', signIn: '使用 Google 登录', started: '已启动 Google 登录。完成登录后即可继续。'),
    (tag: 'zh-Hant', signIn: '使用 Google 登入', started: '已啟動 Google 登入。完成登入後即可繼續。'),
  ]) {
    testWidgets('${localized.tag} pending Google sign-in does not claim completion', (tester) async {
      final dependencies = await createTestDependencies();
      addTearDown(dependencies.repository.close);
      final injected = AppDependencies(
        configuration: dependencies.configuration,
        authService: _ReturningSignInAuth(dependencies.authService, null),
        syncService: dependencies.syncService,
        learningEngine: dependencies.learningEngine,
        repository: dependencies.repository,
      );
      await tester.pumpWidget(BopomofoApp(dependencies: injected, localeController: await _locale(localized.tag)));
      await tester.tap(find.byKey(const ValueKey('nav-settings')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(localized.signIn));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('settings-status')),
        300,
        scrollable: find.byType(Scrollable).last,
      );

      expect(find.text(localized.started), findsOneWidget);
      expect(find.text('Google sign-in complete.'), findsNothing);
      expect(find.text('Google 登录成功。'), findsNothing);
      expect(find.text('Google 登入成功。'), findsNothing);
    });
  }

  testWidgets('non-null Google sign-in result shows completion', (tester) async {
    final dependencies = await createTestDependencies();
    addTearDown(dependencies.repository.close);
    final injected = AppDependencies(
      configuration: dependencies.configuration,
      authService: _ReturningSignInAuth(dependencies.authService, dependencies.authService.currentUser),
      syncService: dependencies.syncService,
      learningEngine: dependencies.learningEngine,
      repository: dependencies.repository,
    );
    await tester.pumpWidget(BopomofoApp(dependencies: injected, localeController: await _locale('en')));
    await tester.tap(find.byKey(const ValueKey('nav-settings')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign in with Google'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('settings-status')),
      300,
      scrollable: find.byType(Scrollable).last,
    );

    expect(find.text('Google sign-in complete.'), findsOneWidget);
    expect(find.text('Google sign-in started. Complete sign-in to continue.'), findsNothing);
  });

  final cases = [
    (tag: 'en', practice: 'Keyboard practice', shown: 'Type this symbol: ㄅ', hidden: 'Type the hidden symbol', hide: 'Hide labels', show: 'Show labels', metrics: 'Accuracy 0% · CPM 0', account: 'Account', delete: 'Delete account', confirm: 'Delete account?', local: 'Delete local learning data too', cancel: 'Cancel', failure: 'Could not finish account deletion. Check your account and local progress before retrying.'),
    (tag: 'zh-Hans', practice: '键盘练习', shown: '输入这个符号：ㄅ', hidden: '输入隐藏的符号', hide: '隐藏标签', show: '显示标签', metrics: '准确率 0% · 每分钟字符数 0', account: '账户', delete: '删除账户', confirm: '删除账户？', local: '同时删除本机学习数据', cancel: '取消', failure: '无法完成账户删除。请检查账户和本机学习进度后重试。'),
    (tag: 'zh-Hant', practice: '鍵盤練習', shown: '輸入這個符號：ㄅ', hidden: '輸入隱藏的符號', hide: '隱藏標籤', show: '顯示標籤', metrics: '準確率 0% · 每分鐘字元數 0', account: '帳戶', delete: '刪除帳戶', confirm: '刪除帳戶？', local: '同時刪除本機學習資料', cancel: '取消', failure: '無法完成帳戶刪除。請檢查帳戶與本機學習進度後重試。'),
  ];

  for (final localized in cases) {
    testWidgets('${localized.tag} keyboard prompt and metrics follow label visibility', (tester) async {
      final dependencies = await createTestDependencies();
      addTearDown(dependencies.repository.close);
      await tester.pumpWidget(BopomofoApp(dependencies: dependencies, localeController: await _locale(localized.tag)));
      Navigator.of(tester.element(find.byType(AppScaffold))).pushNamed('/keyboard');
      await tester.pumpAndSettle();

      expect(find.text(localized.practice), findsOneWidget);
      expect(find.text(localized.shown), findsOneWidget);
      expect(find.text(localized.metrics), findsOneWidget);
      expect(find.text(localized.hide), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('keyboard-toggle-labels')));
      await tester.pumpAndSettle();
      expect(find.text(localized.hidden), findsOneWidget);
      expect(find.text(localized.shown), findsNothing);
      expect(find.text(localized.show), findsOneWidget);
    });

    testWidgets('${localized.tag} account deletion cancel preserves account page', (tester) async {
      final dependencies = await createTestDependencies();
      addTearDown(dependencies.repository.close);
      await tester.pumpWidget(BopomofoApp(dependencies: dependencies, localeController: await _locale(localized.tag)));
      Navigator.of(tester.element(find.byType(AppScaffold))).pushNamed('/account');
      await tester.pumpAndSettle();

      expect(find.text(localized.account), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('account-delete')));
      await tester.pumpAndSettle();
      expect(find.text(localized.confirm), findsOneWidget);
      expect(find.text(localized.local), findsOneWidget);
      await tester.tap(find.text(localized.cancel));
      await tester.pumpAndSettle();
      expect(find.text(localized.account), findsOneWidget);
      expect(find.byKey(const ValueKey('account-status')), findsNothing);
    });

    testWidgets('${localized.tag} account failure hides diagnostic text', (tester) async {
      final dependencies = await createTestDependencies();
      addTearDown(dependencies.repository.close);
      final failing = AppDependencies(
        configuration: dependencies.configuration,
        authService: _FailingDeleteAuth(dependencies.authService),
        syncService: dependencies.syncService,
        learningEngine: dependencies.learningEngine,
        repository: dependencies.repository,
      );
      await tester.pumpWidget(BopomofoApp(dependencies: failing, localeController: await _locale(localized.tag)));
      Navigator.of(tester.element(find.byType(AppScaffold))).pushNamed('/account');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('account-delete')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('confirm-delete-account')));
      await tester.pumpAndSettle();

      expect(find.text(localized.failure), findsOneWidget);
      expect(find.textContaining('private deletion detail'), findsNothing);
    });
  }

  for (final statusCase in [
    (status: SyncStatus.localOnly, expected: 'Progress is saved locally.'),
    (status: SyncStatus.pending, expected: 'Sync pending. Local progress remains safe.'),
    (status: SyncStatus.synced, expected: 'Progress synced.'),
    (status: SyncStatus.offline, expected: 'Sync is unavailable offline. Local progress remains safe.'),
    (status: SyncStatus.error, expected: 'Sync failed. Local progress remains safe; try again later.'),
  ]) {
    testWidgets('sync ${statusCase.status.name} ignores arbitrary service message', (tester) async {
      final dependencies = await createTestDependencies();
      addTearDown(dependencies.repository.close);
      final injected = AppDependencies(
        configuration: dependencies.configuration,
        authService: dependencies.authService,
        syncService: _ResultSyncService(SyncResult(status: statusCase.status, message: 'private server detail')),
        learningEngine: dependencies.learningEngine,
        repository: dependencies.repository,
      );
      await tester.pumpWidget(BopomofoApp(dependencies: injected, localeController: await _locale('en')));
      await tester.tap(find.byKey(const ValueKey('nav-settings')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Sync now'));
      await tester.tap(find.text('Sync now'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('settings-status')),
        300,
        scrollable: find.byType(Scrollable).last,
      );

      expect(find.descendant(
        of: find.byKey(const ValueKey('settings-status')),
        matching: find.text(statusCase.expected),
      ), findsOneWidget);
      expect(find.textContaining('private server detail'), findsNothing);
    });
  }
}
