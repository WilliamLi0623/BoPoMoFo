import 'package:bopomofo/localization/app_locale_controller.dart';
import 'package:bopomofo/localization/locale_preference_store.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const hans = Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans');
  const hant = Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant');

  group('resolveDefaultLocale', () {
    final cases = <({String name, List<Locale> locales, Locale expected})>[
      (
        name: 'explicit Hant script',
        locales: [const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant')],
        expected: hant,
      ),
      (name: 'TW region', locales: [const Locale('zh', 'TW')], expected: hant),
      (name: 'HK region', locales: [const Locale('zh', 'HK')], expected: hant),
      (name: 'MO region', locales: [const Locale('zh', 'MO')], expected: hant),
      (
        name: 'explicit Hans script',
        locales: [const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans')],
        expected: hans,
      ),
      (name: 'CN region', locales: [const Locale('zh', 'CN')], expected: hans),
      (name: 'SG region', locales: [const Locale('zh', 'SG')], expected: hans),
      (name: 'bare Chinese', locales: [const Locale('zh')], expected: hans),
      (name: 'unknown Chinese region', locales: [const Locale('zh', 'XX')], expected: hans),
      (name: 'non-Chinese first locale', locales: [const Locale('en', 'US')], expected: hans),
      (name: 'empty locale list', locales: [], expected: hans),
      (
        name: 'first Chinese locale controls resolution',
        locales: [const Locale('zh', 'TW'), const Locale('zh', 'CN')],
        expected: hant,
      ),
      (
        name: 'later Chinese locale does not override non-Chinese first locale',
        locales: [const Locale('en', 'US'), const Locale('zh', 'TW')],
        expected: hans,
      ),
    ];

    for (final testCase in cases) {
      test(testCase.name, () {
        expect(resolveDefaultLocale(testCase.locales), testCase.expected);
      });
    }
  });

  test('load uses a supported stored locale', () async {
    final store = _MemoryLocalePreferenceStore('zh-Hant');

    final controller = await AppLocaleController.load(
      store: store,
      platformLocales: const [Locale('zh', 'CN')],
    );

    expect(controller.locale, hant);
  });

  test('load restores stored English', () async {
    final store = _MemoryLocalePreferenceStore('en');

    final controller = await AppLocaleController.load(
      store: store,
      platformLocales: const [Locale('zh', 'TW')],
    );

    expect(controller.locale, const Locale('en'));
  });

  test('load ignores an unsupported stored locale and resolves the platform', () async {
    final store = _MemoryLocalePreferenceStore('en-US');

    final controller = await AppLocaleController.load(
      store: store,
      platformLocales: const [Locale('zh', 'TW')],
    );

    expect(controller.locale, hant);
  });

  test('select updates listeners immediately and persists the selected tag', () async {
    final store = _MemoryLocalePreferenceStore();
    final controller = await AppLocaleController.load(
      store: store,
      platformLocales: const [Locale('zh', 'CN')],
    );
    var notified = false;
    controller.addListener(() => notified = true);

    final persisted = await controller.select(hant);

    expect(notified, isTrue);
    expect(controller.locale, hant);
    expect(persisted, isTrue);
    expect(store.localeTag, 'zh-Hant');
  });

  test('select updates listeners immediately and persists English as en', () async {
    final store = _MemoryLocalePreferenceStore();
    final controller = await AppLocaleController.load(
      store: store,
      platformLocales: const [Locale('zh', 'CN')],
    );
    var notified = false;
    controller.addListener(() => notified = true);

    final selection = controller.select(const Locale('en'));

    expect(controller.locale, const Locale('en'));
    expect(notified, isTrue);
    expect(await selection, isTrue);
    expect(store.localeTag, 'en');
  });

  test('select returns false when persistence fails and keeps the selected locale', () async {
    final store = _MemoryLocalePreferenceStore()..failWrites = true;
    final controller = await AppLocaleController.load(
      store: store,
      platformLocales: const [Locale('zh', 'CN')],
    );

    expect(await controller.select(hant), isFalse);
    expect(controller.locale, hant);
  });
}

class _MemoryLocalePreferenceStore implements LocalePreferenceStore {
  _MemoryLocalePreferenceStore([this.localeTag]);

  String? localeTag;
  bool failWrites = false;

  @override
  Future<String?> readLocaleTag() async => localeTag;

  @override
  Future<void> writeLocaleTag(String localeTag) async {
    if (failWrites) throw StateError('write failed');
    this.localeTag = localeTag;
  }
}
