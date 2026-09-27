import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:design_system/design_system.dart';
import 'package:domain/domain.dart';

import 'package:bopomofo/bootstrap.dart';

import 'test_support.dart';

void main() {
  Future<AppDependencies> dependencies() => createTestDependencies();

  testWidgets('account deletion dialog supports keeping local data', (tester) async {
    final deps = await dependencies();
    await deps.repository.recordReview(ReviewAttempt(
      itemId: 'ㄅ',
      skill: Skill.keyboard,
      correct: true,
      occurredAt: DateTime.utc(2026, 9, 23),
    ));
    await tester.pumpWidget(BopomofoApp(dependencies: deps, localeController: await createEnglishLocaleController()));
    await tester.tap(find.byKey(const ValueKey('nav-settings')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('settings-account')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('account-delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-delete-account')));
    await tester.pumpAndSettle();

    expect(find.text('Learn Bopomofo from what you already know.'), findsOneWidget);
    expect((await deps.repository.snapshot()).reviewStates, isNotEmpty);
    await deps.repository.close();
  });

  testWidgets('account deletion dialog can clear local data', (tester) async {
    final deps = await dependencies();
    await deps.repository.recordReview(ReviewAttempt(
      itemId: 'ㄅ',
      skill: Skill.keyboard,
      correct: true,
      occurredAt: DateTime.utc(2026, 9, 23),
    ));
    await tester.pumpWidget(BopomofoApp(dependencies: deps, localeController: await createEnglishLocaleController()));
    await tester.tap(find.byKey(const ValueKey('nav-settings')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('settings-account')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('account-delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('delete-local-data')));
    await tester.tap(find.byKey(const ValueKey('confirm-delete-account')));
    await tester.pumpAndSettle();

    expect(find.text('Learn Bopomofo from what you already know.'), findsOneWidget);
    expect((await deps.repository.snapshot()).reviewStates, isEmpty);
    await deps.repository.close();
  });

  testWidgets('named account route returns to guest after deletion', (tester) async {
    final deps = await dependencies();
    await tester.pumpWidget(BopomofoApp(dependencies: deps, localeController: await createEnglishLocaleController()));
    Navigator.of(tester.element(find.byType(AppScaffold))).pushNamed('/account');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('account-delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-delete-account')));
    await tester.pumpAndSettle();

    expect(find.text('Learn Bopomofo from what you already know.'), findsOneWidget);
    await deps.repository.close();
  });

  testWidgets('named onboarding route starts the selected lesson', (tester) async {
    final deps = await dependencies();
    await tester.pumpWidget(BopomofoApp(dependencies: deps, localeController: await createEnglishLocaleController()));
    Navigator.of(tester.element(find.byType(AppScaffold))).pushNamed('/');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('path-sounds')));
    await tester.pumpAndSettle();

    expect(find.text('Your first lesson'), findsOneWidget);
    expect(find.text('Listen for the shape and sound of each symbol.'), findsOneWidget);
    await tester.tap(find.text('Review due items').last);
    await tester.pumpAndSettle();
    expect(find.text('Recognition review'), findsOneWidget);
    await deps.repository.close();
  });

  testWidgets('export action delivers JSON through the injected callback', (tester) async {
    String? exported;
    final deps = await dependencies();
    await tester.pumpWidget(BopomofoApp(
      dependencies: deps,
      localeController: await createEnglishLocaleController(),
      onExportReady: (value) => exported = value,
    ));
    await tester.tap(find.byKey(const ValueKey('nav-settings')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Export progress'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.textContaining('Export ready'),
      300,
      scrollable: find
          .ancestor(of: find.text('Settings'), matching: find.byType(Scrollable))
          .first,
    );

    expect(exported, contains('schemaVersion'));
    expect(find.textContaining('Export ready'), findsOneWidget);
    await deps.repository.close();
  });

  testWidgets('keyboard renders all symbols and reports offline listening fallback', (tester) async {
    final deps = await dependencies();
    await tester.pumpWidget(BopomofoApp(dependencies: deps, localeController: await createEnglishLocaleController()));
    Navigator.of(tester.element(find.byType(AppScaffold))).pushNamed('/keyboard');
    await tester.pumpAndSettle();

    expect(find.byType(OutlinedButton), findsNWidgets(37));
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('keyboard-listening')),
      300,
      scrollable: find.ancestor(
        of: find.text('Keyboard practice'),
        matching: find.byType(Scrollable),
      ).first,
    );
    await tester.tap(find.byKey(const ValueKey('keyboard-listening')));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const ValueKey('keyboard-page')),
      const Offset(0, -400),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('keyboard-listening-unavailable')), findsOneWidget);
    await deps.repository.close();
  });
}
