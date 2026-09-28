import 'package:bopomofo/localization/shared_preferences_locale_preference_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('reads and writes the canonical app_locale value', () async {
    final preferences = await SharedPreferences.getInstance();
    final store = SharedPreferencesLocalePreferenceStore(preferences);

    expect(await store.readLocaleTag(), isNull);
    await store.writeLocaleTag('zh-Hant');
    expect(preferences.getString('app_locale'), 'zh-Hant');
    expect(await store.readLocaleTag(), 'zh-Hant');
  });

  test('ignores a stored tag outside the supported set', () async {
    SharedPreferences.setMockInitialValues({'app_locale': 'en-US'});
    final preferences = await SharedPreferences.getInstance();
    final store = SharedPreferencesLocalePreferenceStore(preferences);

    expect(await store.readLocaleTag(), isNull);
  });
}
