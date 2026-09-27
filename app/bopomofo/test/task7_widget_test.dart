import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:design_system/design_system.dart';

import 'package:bopomofo/bootstrap.dart';

import 'test_support.dart';

void main() {
  Future<AppDependencies> dependencies() => createTestDependencies();

  testWidgets('onboarding offers the three learning paths', (tester) async {
    await tester.pumpWidget(
      BopomofoApp(dependencies: await dependencies(), localeController: await createEnglishLocaleController()),
    );

    expect(find.text('Bopomofo'), findsOneWidget);
    expect(find.text('Learn Bopomofo from what you already know.'), findsOneWidget);
    expect(find.text('Start with Pinyin'), findsOneWidget);
    expect(find.text('Start with sounds'), findsOneWidget);
    expect(find.text('I am new to Chinese'), findsOneWidget);
    expect(find.text('Progress is saved locally.'), findsOneWidget);
  });

  testWidgets('guest review saves locally and shows the next prompt', (tester) async {
    await tester.pumpWidget(
      BopomofoApp(dependencies: await dependencies(), localeController: await createEnglishLocaleController()),
    );

    await tester.tap(find.byKey(const ValueKey('path-pinyin')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Review due items'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('review-prompt-ㄅ')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('review-answer-correct')));
    await tester.pumpAndSettle();

    expect(find.text('Saved locally'), findsOneWidget);
    expect(find.text('Next prompt'), findsOneWidget);
  });

  testWidgets('dashboard separates mastery projections and due status', (tester) async {
    await tester.pumpWidget(
      BopomofoApp(dependencies: await dependencies(), localeController: await createEnglishLocaleController()),
    );

    await tester.tap(find.byKey(const ValueKey('nav-dashboard')));
    await tester.pumpAndSettle();

    expect(find.text('Recognition'), findsOneWidget);
    expect(find.text('Listening'), findsOneWidget);
    expect(find.text('Pinyin conversion'), findsOneWidget);
    expect(find.text('Keyboard'), findsOneWidget);
    expect(find.text('Hanzi input'), findsOneWidget);
    expect(find.textContaining('Due reviews'), findsOneWidget);
    expect(find.textContaining('Confusion targets'), findsOneWidget);
    expect(find.text('Due reviews: 0'), findsOneWidget);
    expect(find.text('Mastered items: 0'), findsOneWidget);
    expect(find.text('Confusion targets: 0'), findsOneWidget);
    expect(find.text('0%'), findsNWidgets(5));
  });

  testWidgets('settings exposes account, sync, data, and deletion actions', (tester) async {
    await tester.pumpWidget(
      BopomofoApp(dependencies: await dependencies(), localeController: await createEnglishLocaleController()),
    );

    await tester.tap(find.byKey(const ValueKey('nav-settings')));
    await tester.pumpAndSettle();

    expect(find.text('Account'), findsOneWidget);
    expect(find.text('Sync now'), findsOneWidget);
    expect(find.text('Export progress'), findsOneWidget);
    expect(find.text('Import progress'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
    expect(find.text('Sign in with Google'), findsOneWidget);
    expect(find.text('Progress is saved locally.'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Delete account'),
      300,
      scrollable: find.ancestor(
        of: find.text('Settings'),
        matching: find.byType(Scrollable),
      ).first,
    );
    expect(find.text('Delete account'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Sync now'),
      -300,
      scrollable: find.ancestor(
        of: find.text('Settings'),
        matching: find.byType(Scrollable),
      ).first,
    );
    await tester.tap(find.text('Sync now'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.textContaining('Sync failed'),
      300,
      scrollable: find.ancestor(
        of: find.text('Settings'),
        matching: find.byType(Scrollable),
      ).first,
    );
    expect(find.textContaining('Sync failed'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Export progress'),
      -300,
      scrollable: find.ancestor(
        of: find.text('Settings'),
        matching: find.byType(Scrollable),
      ).first,
    );
    await tester.tap(find.text('Export progress'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Export ready'), findsOneWidget);
  });

  testWidgets('named keyboard route is registered', (tester) async {
    await tester.pumpWidget(BopomofoApp(dependencies: await dependencies(), localeController: await createEnglishLocaleController()));
    Navigator.of(tester.element(find.byType(AppScaffold))).pushNamed('/keyboard');
    await tester.pumpAndSettle();

    expect(find.text('Keyboard practice'), findsOneWidget);
  });
}
