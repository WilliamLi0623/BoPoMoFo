import 'package:bopomofo/bootstrap.dart';
import 'package:bopomofo/features/review/review_page.dart';
import 'package:bopomofo/routes.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_support.dart';

void main() {
  testWidgets('named review route has a safe screen and a back button',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 600);
    tester.view.padding =
        const FakeViewPadding(left: 24, right: 32, bottom: 40);
    tester.view.viewPadding =
        const FakeViewPadding(left: 24, right: 32, bottom: 40);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(BopomofoApp(
      dependencies: await createTestDependencies(),
      localeController: await createEnglishLocaleController(),
      reviewSessionFactory: () async => throw StateError('fixture unavailable'),
    ));
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.byKey(const ValueKey('start-learning'))))
        .pushNamed(AppRoutes.review);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
        find.ancestor(
            of: find.byType(ReviewPage), matching: find.byType(Scaffold)),
        findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
    expect(
        find.ancestor(
            of: find.byType(ReviewPage), matching: find.byType(SafeArea)),
        findsOneWidget);
    final reviewBounds = tester.getRect(find.byType(ReviewPage));
    expect(reviewBounds.left, greaterThanOrEqualTo(24));
    expect(reviewBounds.right, lessThanOrEqualTo(768));
    expect(reviewBounds.bottom, lessThanOrEqualTo(560));
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('start-learning')), findsOneWidget);
  });
}
