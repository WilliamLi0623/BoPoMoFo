import 'dart:async';

import 'package:bopomofo/app.dart';
import 'package:bopomofo/localization/app_locale_controller.dart';
import 'package:bopomofo/localization/locale_preference_store.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_support.dart';

void main() {
  testWidgets('language selection updates shell and persists each canonical tag', (tester) async {
    final store = _MemoryStore();
    final controller = await AppLocaleController.load(
      store: store,
      platformLocales: const [Locale('zh', 'CN')],
    );
    await tester.pumpWidget(BopomofoApp(
      dependencies: await createTestDependencies(),
      localeController: controller,
    ));
    expect(tester.widget<MaterialApp>(find.byType(MaterialApp)).supportedLocales, [
      const Locale('en'),
      const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
      const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
    ]);
    await tester.tap(find.byKey(const ValueKey('nav-settings')));
    await tester.pumpAndSettle();

    for (final selection in [
      (nativeName: '繁體中文', tag: 'zh-Hant', home: '首頁', dashboard: '儀表板', settings: '設定'),
      (nativeName: 'English', tag: 'en', home: 'Home', dashboard: 'Dashboard', settings: 'Settings'),
      (nativeName: '简体中文', tag: 'zh-Hans', home: '首页', dashboard: '仪表盘', settings: '设置'),
    ]) {
      await tester.tap(find.byKey(const ValueKey('settings-language')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(selection.nativeName).last);
      await tester.pumpAndSettle();
      expect(store.localeTag, selection.tag);
      expect(find.text(selection.home), findsWidgets);
      expect(find.text(selection.dashboard), findsWidgets);
      expect(find.text(selection.settings), findsWidgets);
      expect(find.text(selection.nativeName), findsWidgets);
    }
  });

  testWidgets('relaunch loads saved choice over a different device locale', (tester) async {
    final store = _MemoryStore('en');
    final first = await AppLocaleController.load(
      store: store,
      platformLocales: const [Locale('zh', 'CN')],
    );
    await tester.pumpWidget(BopomofoApp(
      dependencies: await createTestDependencies(),
      localeController: first,
    ));
    expect(find.text('Home'), findsWidgets);

    await tester.pumpWidget(const SizedBox());
    final second = await AppLocaleController.load(
      store: store,
      platformLocales: const [Locale('zh', 'TW')],
    );
    await tester.pumpWidget(BopomofoApp(
      dependencies: await createTestDependencies(),
      localeController: second,
    ));
    expect(find.text('Home'), findsWidgets);
    expect(second.locale, const Locale('en'));
  });

  testWidgets('failed save keeps language and shows localized warning', (tester) async {
    final store = _MemoryStore()..failWrites = true;
    final controller = await AppLocaleController.load(
      store: store,
      platformLocales: const [Locale('zh', 'CN')],
    );
    await tester.pumpWidget(BopomofoApp(
      dependencies: await createTestDependencies(),
      localeController: controller,
    ));
    await tester.tap(find.byKey(const ValueKey('nav-settings')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('settings-language')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('繁體中文').last);
    await tester.pumpAndSettle();

    expect(find.text('首頁'), findsWidgets);
    expect(find.text('語言'), findsWidgets);
    expect(find.text('語言設定可能無法儲存。'), findsOneWidget);
    expect(store.localeTag, isNull);
  });

  testWidgets('late save results cannot change warning for the latest selection', (tester) async {
    final store = _MemoryStore()..holdWrites = true;
    final controller = await AppLocaleController.load(
      store: store,
      platformLocales: const [Locale('zh', 'CN')],
    );
    await tester.pumpWidget(BopomofoApp(
      dependencies: await createTestDependencies(),
      localeController: controller,
    ));
    await tester.tap(find.byKey(const ValueKey('nav-settings')));
    await tester.pumpAndSettle();

    Future<void> choose(String nativeName) async {
      await tester.tap(find.byKey(const ValueKey('settings-language')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(nativeName).last);
      await tester.pumpAndSettle();
    }

    await choose('繁體中文');
    await choose('English');
    expect(store.pendingWrites.map((write) => write.tag).toList(), [
      'zh-Hant',
      'en',
    ]);

    store.pendingWrites[1].completion.complete();
    await tester.pumpAndSettle();
    store.pendingWrites[0].completion.completeError(StateError('older save failed'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('language-save-warning')), findsNothing);
    expect(controller.locale, const Locale('en'));

    await choose('繁體中文');
    await choose('English');
    store.pendingWrites[3].completion.completeError(StateError('current save failed'));
    await tester.pumpAndSettle();
    store.pendingWrites[2].completion.complete();
    await tester.pumpAndSettle();
    expect(find.text('Your language choice may not be saved.'), findsOneWidget);
    expect(controller.locale, const Locale('en'));
  });
}

class _MemoryStore implements LocalePreferenceStore {
  _MemoryStore([this.localeTag]);

  String? localeTag;
  bool failWrites = false;
  bool holdWrites = false;
  final List<({String tag, Completer<void> completion})> pendingWrites = [];

  @override
  Future<String?> readLocaleTag() async => localeTag;

  @override
  Future<void> writeLocaleTag(String value) async {
    if (failWrites) throw StateError('write failed');
    if (holdWrites) {
      final completion = Completer<void>();
      pendingWrites.add((tag: value, completion: completion));
      await completion.future;
    }
    localeTag = value;
  }
}
