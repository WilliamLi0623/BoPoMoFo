abstract interface class LocalePreferenceStore {
  Future<String?> readLocaleTag();

  Future<void> writeLocaleTag(String localeTag);
}
