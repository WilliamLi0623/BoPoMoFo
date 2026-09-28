import 'package:flutter/widgets.dart';

import 'locale_preference_store.dart';

const _hansLocale = Locale.fromSubtags(
  languageCode: 'zh',
  scriptCode: 'Hans',
);
const _hantLocale = Locale.fromSubtags(
  languageCode: 'zh',
  scriptCode: 'Hant',
);

Locale resolveDefaultLocale(List<Locale> platformLocales) {
  if (platformLocales.isEmpty) return _hansLocale;

  final locale = platformLocales.first;
  if (locale.languageCode.toLowerCase() != 'zh') return _hansLocale;

  switch (locale.scriptCode?.toLowerCase()) {
    case 'hans':
      return _hansLocale;
    case 'hant':
      return _hantLocale;
  }

  switch (locale.countryCode?.toUpperCase()) {
    case 'TW':
    case 'HK':
    case 'MO':
      return _hantLocale;
    default:
      return _hansLocale;
  }
}

class AppLocaleController extends ChangeNotifier {
  AppLocaleController._({
    required LocalePreferenceStore store,
    required Locale locale,
  }) : _store = store,
       _locale = locale;

  final LocalePreferenceStore _store;
  Locale _locale;

  Locale get locale => _locale;

  static Future<AppLocaleController> load({
    required LocalePreferenceStore store,
    required List<Locale> platformLocales,
  }) async {
    Locale? storedLocale;
    try {
      storedLocale = _localeForTag(await store.readLocaleTag());
    } on Object {
      // A broken preference backend must not prevent app startup.
    }
    final locale = storedLocale ?? resolveDefaultLocale(platformLocales);
    return AppLocaleController._(store: store, locale: locale);
  }

  Future<bool> select(Locale locale) async {
    final localeTag = _tagForLocale(locale);
    if (localeTag == null) return false;

    _locale = _localeForTag(localeTag)!;
    notifyListeners();
    try {
      await _store.writeLocaleTag(localeTag);
      return true;
    } on Object {
      return false;
    }
  }

  static Locale? _localeForTag(String? localeTag) => switch (localeTag) {
        'en' => const Locale('en'),
        'zh-Hans' => _hansLocale,
        'zh-Hant' => _hantLocale,
        _ => null,
      };

  static String? _tagForLocale(Locale locale) {
    if (locale.languageCode.toLowerCase() == 'en' &&
        locale.scriptCode == null &&
        locale.countryCode == null) {
      return 'en';
    }
    if (locale.languageCode.toLowerCase() != 'zh') return null;
    return switch (locale.scriptCode?.toLowerCase()) {
      'hans' => 'zh-Hans',
      'hant' => 'zh-Hant',
      _ => null,
    };
  }
}
