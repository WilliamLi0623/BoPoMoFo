import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:bopomofo/bootstrap.dart';

import 'test_support.dart';

void main() {
  testWidgets('guest can reach start learning without a network client', (
    tester,
  ) async {
    await tester.pumpWidget(
      BopomofoApp(
        dependencies: await createTestDependencies(),
      ),
    );

    expect(find.text('Bopomofo'), findsOneWidget);
    expect(find.text('Start Learning'), findsOneWidget);
    expect(find.text('Guest mode · saved locally'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('start-learning')));
    await tester.pump();

    expect(find.text('Learning started'), findsOneWidget);
    expect(find.text('Start Learning'), findsNothing);
  });
}
