import 'package:auth/auth.dart';
import 'package:bopomofo/bootstrap.dart';
import 'package:bopomofo/localization/app_locale_controller.dart';
import 'package:bopomofo/localization/locale_preference_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_support.dart';

class _LocaleStore implements LocalePreferenceStore {
  const _LocaleStore(this.tag);

  final String tag;

  @override
  Future<String?> readLocaleTag() async => tag;

  @override
  Future<void> writeLocaleTag(String localeTag) async {}
}

class _FailingAuthService implements AuthService {
  const _FailingAuthService(this.delegate, this.failure);

  final AuthService delegate;
  final Object failure;

  @override
  Stream<AuthState> get authStateChanges => delegate.authStateChanges;

  @override
  User? get currentUser => delegate.currentUser;

  @override
  Future<User?> signInWithGoogle() => Future<User?>.error(failure);

  @override
  Future<User?> signInWithApple() => delegate.signInWithApple();

  @override
  Future<void> signOut() => delegate.signOut();

  @override
  Future<void> deleteAccount() => delegate.deleteAccount();
}

void main() {
  final cases = [
    (
      tag: 'en',
      intro: 'Learn Bopomofo from what you already know.',
      path: 'Start with Pinyin',
      lesson: 'Your first lesson',
      today: 'Today: ㄅ',
      review: 'Review due items',
      prompt: 'Which sound does ㄅ represent?',
      saved: 'Correct answer saved locally.',
      next: 'Continue',
      secondPrompt: 'Which sound does ㄆ represent?',
      progress: 'Your progress',
      due: 'Due reviews: 0',
      mastered: 'Mastered items: 0',
    ),
    (
      tag: 'zh-Hans',
      intro: '从你熟悉的知识开始学习注音。',
      path: '从拼音开始',
      lesson: '第一课',
      today: '今天：ㄅ',
      review: '复习待复习项目',
      prompt: '这个符号代表什么读音？ㄅ',
      saved: '回答正确，已保存到本机。',
      next: '继续',
      secondPrompt: '这个符号代表什么读音？ㄆ',
      progress: '你的学习进度',
      due: '待复习：0 项',
      mastered: '已掌握：0 项',
    ),
    (
      tag: 'zh-Hant',
      intro: '從你熟悉的知識開始學習注音。',
      path: '從拼音開始',
      lesson: '第一課',
      today: '今天：ㄅ',
      review: '複習待複習項目',
      prompt: '這個符號代表什麼讀音？ㄅ',
      saved: '回答正確，已儲存到本機。',
      next: '繼續',
      secondPrompt: '這個符號代表什麼讀音？ㄆ',
      progress: '你的學習進度',
      due: '待複習：0 項',
      mastered: '已掌握：0 項',
    ),
  ];

  for (final localized in cases) {
    testWidgets('${localized.tag} learning flow uses localized copy', (tester) async {
      final controller = await AppLocaleController.load(
        store: _LocaleStore(localized.tag),
        platformLocales: const [Locale('en')],
      );
      final dependencies = await createTestDependencies();
      addTearDown(dependencies.repository.close);
      await tester.pumpWidget(BopomofoApp(
        dependencies: dependencies,
        localeController: controller,
        reviewSessionFactory:
            createTestReviewSessionFactory(store: dependencies.repository),
      ));

      expect(find.text('Bopomofo'), findsOneWidget);
      expect(find.text(localized.intro), findsOneWidget);
      expect(find.text(localized.path), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('path-pinyin')));
      await tester.pumpAndSettle();

      expect(find.text(localized.lesson), findsOneWidget);
      expect(find.text(localized.today), findsOneWidget);
      await tester.tap(find.text(localized.review));
      await tester.pumpAndSettle();

      expect(find.text(localized.prompt), findsOneWidget);
      expect(find.text('1 / 2'), findsOneWidget);
      expect(find.byKey(const ValueKey('quiz-option-ba')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('quiz-option-ba')));
      await tester.pumpAndSettle();

      expect(find.text(localized.saved), findsOneWidget);
      expect(find.text(localized.next), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('quiz-continue')));
      await tester.pumpAndSettle();
      expect(find.text('2 / 2'), findsOneWidget);
      expect(find.text(localized.secondPrompt), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('nav-dashboard')));
      await tester.pumpAndSettle();

      expect(find.text(localized.progress), findsOneWidget);
      expect(find.text(localized.due), findsOneWidget);
      expect(find.text(localized.mastered), findsOneWidget);
      expect(find.text('0%'), findsNWidgets(4));
    });
  }

  for (final failureCase in [
    (
      failure: StateError('private oauth detail'),
      expected: 'Google sign-in is unavailable. Keep learning offline and try again later.',
    ),
    (
      failure: const AuthFailure(
        kind: AuthFailureKind.cancelled,
        message: 'private oauth detail',
      ),
      expected: 'Google sign-in cancelled.',
    ),
  ]) {
    testWidgets('sign-in failure hides exception details: ${failureCase.expected}', (tester) async {
      final dependencies = await createTestDependencies();
      addTearDown(dependencies.repository.close);
      final failingDependencies = AppDependencies(
        configuration: dependencies.configuration,
        authService: _FailingAuthService(dependencies.authService, failureCase.failure),
        syncService: dependencies.syncService,
        learningEngine: dependencies.learningEngine,
        repository: dependencies.repository,
      );
      await tester.pumpWidget(BopomofoApp(
        dependencies: failingDependencies,
        localeController: await AppLocaleController.load(
          store: const _LocaleStore('en'),
          platformLocales: const [Locale('en')],
        ),
      ));

      await tester.ensureVisible(find.text('Sign in with Google'));
      await tester.tap(find.text('Sign in with Google'));
      await tester.pumpAndSettle();

      expect(find.text(failureCase.expected), findsOneWidget);
      expect(find.textContaining('private oauth detail'), findsNothing);
    });
  }
}
