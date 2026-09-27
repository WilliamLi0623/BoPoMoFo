import 'package:shared_preferences/shared_preferences.dart';

import 'locale_preference_store.dart';

class SharedPreferencesLocalePreferenceStore implements LocalePreferenceStore {
  const SharedPreferencesLocalePreferenceStore(this.preferences);

  static const key = 'app_locale';
  static const _supportedTags = {'zh-Hans', 'zh-Hant', 'en'};

  final SharedPreferences preferences;

  @override
  Future<String?> readLocaleTag() async {
    final tag = preferences.getString(key);
    return _supportedTags.contains(tag) ? tag : null;
  }

  @override
  Future<void> writeLocaleTag(String localeTag) async {
    if (!_supportedTags.contains(localeTag)) {
      throw ArgumentError.value(localeTag, 'localeTag', 'Unsupported locale');
    }
    if (!await preferences.setString(key, localeTag)) {
      throw StateError('Could not save locale preference');
    }
  }
}
