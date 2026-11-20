import 'package:bopomofo/bootstrap.dart';
import 'package:design_system/design_system.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_support.dart';

void main() {
  testWidgets('named account route uses a standalone scaffold and app bar',
      (tester) async {
    final dependencies = await createTestDependencies();
    addTearDown(dependencies.repository.close);
    final localeController = await createEnglishLocaleController();

    await tester.pumpWidget(BopomofoApp(
      dependencies: dependencies,
      localeController: localeController,
    ));
    Navigator.of(tester.element(find.byType(AppScaffold)))
        .pushNamed('/account');
    await tester.pumpAndSettle();

    expect(find.byType(Scaffold), findsWidgets);
    expect(find.byType(AppBar), findsOneWidget);
    expect(find.byTooltip('Back'), findsOneWidget);
    expect(find.byKey(const ValueKey('account-delete')), findsOneWidget);
  });
}
