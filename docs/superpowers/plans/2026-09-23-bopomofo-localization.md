# Bopomofo Localization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Localize all app-owned user-facing UI into Simplified Chinese, Traditional Chinese, and English, with a persisted manual choice and device-aware Chinese default, and provide equivalent root READMEs in all three languages.

**Architecture:** Use Flutter `gen_l10n` with three ARB catalogs, and an app-owned locale controller backed by a small preference-store interface. Resolve initial locale from the platform locale unless a valid manual choice is saved; inject generated navigation strings into `design_system` so the shared package stays independent of app localization. Keep language preference local to the device and independent of learning data and sync.

**Tech Stack:** Flutter localization generation, ARB, Dart, `shared_preferences`, Flutter unit/widget/integration tests, PowerShell verification scripts.

**Spec:** `docs/superpowers/specs/2026-09-23-bopomofo-localization-design.md`

## Global Constraints

- Support only `zh_Hans`, `zh_Hant`, and `en` in this change.
- A saved manual choice takes precedence over the device locale; without one, a Chinese platform locale selects its script/region variant and every non-Chinese locale defaults to Simplified Chinese.
- The preference is device-local and must not enter learning export, account sync, or domain models.
- `packages/design_system` must not import generated localization code from `app/bopomofo`.
- All three ARB files must contain matching message keys; dynamic counts use generated locale-aware messages, not English-fragment concatenation.
- App-owned unknown errors use localized generic copy; raw exception strings are not rendered to users.
- Locale changes must not reset learning state, auth state, or sync state.
- `README.md` is Simplified Chinese; `README.zh-TW.md` is Traditional Chinese; `README.en.md` is English. Claims and commands must match the repository.
- Preserve all existing files and user data; stage only files belonging to this plan when committing.
- Finish each task as a separate signed commit after its verification passes; verify each local signature with `git verify-commit HEAD` and each pushed commit through GitHub's commit verification API before continuing.

---

## File Map

```text
app/bopomofo/l10n.yaml                                      gen_l10n configuration
app/bopomofo/pubspec.yaml                                   enable generation and runtime preference dependency
app/bopomofo/lib/l10n/app_en.arb                            English source catalog
app/bopomofo/lib/l10n/app_zh_Hans.arb                       Simplified Chinese catalog
app/bopomofo/lib/l10n/app_zh_Hant.arb                       Traditional Chinese catalog
app/bopomofo/lib/localization/locale_preference_store.dart  preference boundary
app/bopomofo/lib/localization/shared_preferences_locale_preference_store.dart
                                                             device preference adapter
app/bopomofo/lib/localization/app_locale_controller.dart    locale resolution and observable state
app/bopomofo/lib/bootstrap.dart                             initialize locale before runApp
app/bopomofo/lib/app.dart                                   configure MaterialApp and supply localized shell labels
app/bopomofo/lib/features/settings/settings_page.dart      language selector and localized settings/status copy
packages/design_system/lib/src/app_scaffold.dart            accept navigation labels from app
app/bopomofo/lib/features/{onboarding,lesson,review,dashboard,keyboard,account}/
                                                             generated-localization-backed feature copy
app/bopomofo/test/localization/                             resolver, store, and locale widget tests
app/bopomofo/test/test_support.dart                         shared deterministic locale setup for existing widget tests
app/bopomofo/test/{smoke_test,task7_widget_test,task8_widget_test}.dart
                                                             update old English-copy assertions to choose English explicitly
app/bopomofo/integration_test/offline_learning_test.dart     locale-switch data-preservation regression
README.md                                                   Simplified Chinese entry
README.zh-TW.md                                              Traditional Chinese entry
README.en.md                                                 English entry
```

## Task 1: Add localization generation and deterministic locale resolution

**Files:**
- Modify: `app/bopomofo/pubspec.yaml`
- Add: `flutter_localizations` from the Flutter SDK to `app/bopomofo/pubspec.yaml`
- Create: `app/bopomofo/l10n.yaml`
- Create: `app/bopomofo/lib/l10n/app_en.arb`
- Create: `app/bopomofo/lib/l10n/app_zh_Hans.arb`
- Create: `app/bopomofo/lib/l10n/app_zh_Hant.arb`
- Create: `app/bopomofo/lib/localization/locale_preference_store.dart`
- Create: `app/bopomofo/lib/localization/app_locale_controller.dart`
- Test: `app/bopomofo/test/localization/app_locale_controller_test.dart`

**Interfaces:**
- `abstract interface class LocalePreferenceStore { Future<String?> readLocaleTag(); Future<void> writeLocaleTag(String localeTag); }`
- `Locale resolveDefaultLocale(List<Locale> platformLocales)` returns only `Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans')` or `Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant')`.
- `AppLocaleController.load({required LocalePreferenceStore store, required List<Locale> platformLocales})` returns a controller after validating a stored locale or resolving the default.
- `AppLocaleController.locale` is the current `Locale`; `Future<bool> select(Locale locale)` immediately updates listeners, returns `true` if persistence succeeds, and returns `false` if persistence fails.

- [ ] **Step 1: Write failing locale-resolution tests**

Create table-driven tests for these cases:

```dart
expect(resolveDefaultLocale([const Locale.fromSubtags(
  languageCode: 'zh', scriptCode: 'Hant',
)]), const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'));
expect(resolveDefaultLocale([const Locale.fromSubtags(
  languageCode: 'zh', countryCode: 'TW',
)]), const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'));
expect(resolveDefaultLocale([const Locale('zh', 'CN')]),
    const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'));
expect(resolveDefaultLocale([const Locale('en', 'US')]),
    const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'));
```

Also cover explicit Hans script, Hant regions HK/MO, Hans region SG, bare `zh`, an ordered locale list with Chinese first, and a non-Chinese first locale. The first platform locale controls whether the device is treated as Chinese; later entries do not override it.

- [ ] **Step 2: Run the focused test and confirm it fails**

Run from `app/bopomofo`:

```powershell
flutter test test/localization/app_locale_controller_test.dart
```

Expected: compilation fails because `resolveDefaultLocale` is not implemented.

- [ ] **Step 3: Implement locale resolution and the preference-store contract**

In `app_locale_controller.dart`, recognize explicit script `Hans`/`Hant` first; otherwise map `TW`, `HK`, and `MO` to Hant, map `CN` and `SG` to Hans, and map bare/unknown Chinese tags to Hans. If the first platform locale is not Chinese or the list is empty, return Hans. Keep parsing and validation private to the localization layer.

- [ ] **Step 4: Run focused tests and confirm they pass**

Run:

```powershell
flutter test test/localization/app_locale_controller_test.dart
```

Expected: every locale-resolution table case passes.

- [ ] **Step 5: Add ARB generation configuration and valid starter catalogs**

In `pubspec.yaml`, add `flutter_localizations: { sdk: flutter }`, set `flutter: generate: true`, and move `shared_preferences: ^2.3.3` from `dev_dependencies` into `dependencies`. Configure `l10n.yaml` with `arb-dir: lib/l10n`, `template-arb-file: app_en.arb`, `output-localization-file: app_localizations.dart`, and `output-class: AppLocalizations`. Add matching starter metadata and app-name entries to all three ARB files.

- [ ] **Step 6: Generate localization accessors and resolve dependencies**

Run from `app/bopomofo`:

```powershell
flutter pub get
flutter gen-l10n
```

Expected: `AppLocalizations` is generated for English, `zh_Hans`, and `zh_Hant` without ARB parse or missing-plural warnings.

## Task 2: Persist locale choice, wire startup, and localize the app shell

**Files:**
- Create: `app/bopomofo/lib/localization/shared_preferences_locale_preference_store.dart`
- Modify: `app/bopomofo/lib/localization/app_locale_controller.dart`
- Modify: `app/bopomofo/lib/bootstrap.dart`
- Modify: `app/bopomofo/lib/app.dart`
- Modify: `app/bopomofo/lib/features/settings/settings_page.dart`
- Modify: `packages/design_system/lib/src/app_scaffold.dart`
- Modify: all three ARB catalogs
- Test: `app/bopomofo/test/localization/app_locale_controller_test.dart`
- Test: `app/bopomofo/test/localization/language_selector_test.dart`
- Modify: `app/bopomofo/test/test_support.dart`
- Modify: existing tests that construct `BopomofoApp`

**Interfaces:**
- `SharedPreferencesLocalePreferenceStore` implements `LocalePreferenceStore` using the key `app_locale` and stores only `zh-Hans`, `zh-Hant`, or `en`.
- `AppLocaleController.load` accepts the preference adapter and platform locale list; invalid stored tags and read failures use the device-derived default.
- `AppScaffold` receives `homeLabel`, `dashboardLabel`, and `settingsLabel` as required strings; it does not import `AppLocalizations`.
- `BopomofoApp` receives the loaded `AppLocaleController` and passes it to `SettingsPage`.

- [ ] **Step 1: Add controller persistence and failure tests**

Extend controller tests with an in-memory fake store. Verify absent/invalid saved tags use device resolution; each of the three valid tags loads exactly; a saved selection overrides device locale; read exceptions do not block controller creation; and a write exception returns `false` while the selected locale remains active in memory.

- [ ] **Step 2: Run the locale controller tests and confirm new cases fail**

Run:

```powershell
flutter test test/localization/app_locale_controller_test.dart
```

Expected: new persistence cases fail until loading, validation, and write recovery are implemented.

- [ ] **Step 3: Implement the SharedPreferences adapter and controller behavior**

Use a single key `app_locale`. Store canonical tags `zh-Hans`, `zh-Hant`, and `en`; parse only those tags. If `SharedPreferences.setString` returns `false`, surface that as a failed write to the controller. On `select`, notify listeners immediately, then attempt to persist. Catch preference read/write errors inside the controller so they cannot block app startup or the current-session language change.

- [ ] **Step 4: Add ARB entries for app shell and language selector**

Add matching keys in every catalog for the product-shell title, Home, Dashboard, Settings, Language, the three native language names, and the localized “language may not persist” warning. Keep language names in their native form in all three catalogs.

- [ ] **Step 5: Wire locale initialization before app startup**

In `bootstrap()`, initialize Flutter bindings, load the locale controller from `PlatformDispatcher.instance.locales`, then create normal app dependencies and call `runApp(BopomofoApp(...))`. A preference read failure follows the controller fallback and does not bypass the existing app bootstrap.

- [ ] **Step 6: Wire MaterialApp, shared navigation, and Settings language selection**

Set `locale: localeController.locale`, the generated `AppLocalizations.delegate`, `GlobalMaterialLocalizations.delegate`, `GlobalWidgetsLocalizations.delegate`, `GlobalCupertinoLocalizations.delegate`, and `AppLocalizations.supportedLocales` on `MaterialApp`. Listen to the controller so selection rebuilds the app. Pass generated navigation labels to `AppScaffold`; add a Settings language control keyed `settings-language` that calls `select` and shows the localized persistence warning on `false`.

- [ ] **Step 7: Add language-selector widget tests**

Verify each language can be selected, the shell/navigation and selector labels update immediately, and the store receives the canonical tag. Rebuild the app using the same store and verify the saved choice wins over a different simulated device locale. Simulate a failing write and verify the language still changes and localized warning appears.

- [ ] **Step 8: Make existing widget tests explicitly choose English**

Update `test_support.dart` to provide a deterministic in-memory locale controller with an explicit English preference. Pass it to every existing `BopomofoApp` construction in smoke, Task 7/8, and offline integration tests whose assertions expect English. Keep default-locale policy covered only by the dedicated controller tests.

- [ ] **Step 9: Run the focused shell and existing widget tests**

Run from `app/bopomofo`:

```powershell
flutter test test/localization test/smoke_test.dart test/task7_widget_test.dart test/task8_widget_test.dart
```

Expected: localized shell changes do not break existing English-flow assertions or account/learning behavior.

## Task 3: Localize onboarding, lesson, review, and dashboard

**Files:**
- Modify: `app/bopomofo/lib/features/onboarding/onboarding_page.dart`
- Modify: `app/bopomofo/lib/features/lesson/lesson_page.dart`
- Modify: `app/bopomofo/lib/features/review/review_page.dart`
- Modify: `app/bopomofo/lib/features/dashboard/dashboard_page.dart`
- Modify: all three ARB catalogs
- Modify: `app/bopomofo/test/task7_widget_test.dart`
- Test: `app/bopomofo/test/localization/learning_surfaces_localization_test.dart`

**Interfaces:**
- Each feature obtains generated strings from `AppLocalizations.of(context)`; no feature defines its own locale map.
- Count-bearing messages such as due reviews use generated plural arguments.
- Learning path identifiers and domain data remain language-neutral; only displayed labels are localized.

- [ ] **Step 1: Add widget tests for translated learning surfaces**

For each of `zh_Hans`, `zh_Hant`, and `en`, pump the app at onboarding, enter a lesson, submit a review, and open the dashboard. Assert localized headings/actions/status plus invariant Bopomofo symbols and numeric mastery values.

- [ ] **Step 2: Run the focused tests and confirm untranslated UI causes failures**

Run:

```powershell
flutter test test/localization/learning_surfaces_localization_test.dart
```

Expected: Chinese expectations fail against the current hardcoded English copy.

- [ ] **Step 3: Add complete matching ARB messages for these screens**

Translate onboarding intro and path choices, sign-in progress/cancel/failure status, lesson heading/path labels, review prompts/results/next action, dashboard headings/metrics, offline copy, and due/mastered/confusion counts. Use ICU plural syntax for all count messages and placeholders for changing values.

- [ ] **Step 4: Replace hardcoded user-facing text with generated accessors**

Update all four pages, including conditional button/status labels and interpolation. Keep symbols, path keys, quiz correctness, IDs, and internal switch values untouched. Do not make localized text determine application logic.

- [ ] **Step 5: Regenerate catalogs and run the learning-surface tests**

Run:

```powershell
flutter gen-l10n
flutter test test/localization/learning_surfaces_localization_test.dart test/task7_widget_test.dart
```

Expected: each locale shows its own copy, English tests remain stable, and the learning flow still records a correct review.

## Task 4: Localize keyboard, account, deletion, settings actions, and errors

**Files:**
- Modify: `app/bopomofo/lib/features/keyboard/keyboard_page.dart`
- Modify: `app/bopomofo/lib/features/account/account_page.dart`
- Modify: `app/bopomofo/lib/features/account/delete_account_dialog.dart`
- Modify: `app/bopomofo/lib/features/settings/settings_page.dart`
- Modify: all three ARB catalogs
- Modify: `app/bopomofo/test/task8_widget_test.dart`
- Test: `app/bopomofo/test/localization/account_keyboard_localization_test.dart`

**Interfaces:**
- UI-localized operation status is derived from `SyncStatus`, known auth outcomes, and operation result categories; packages continue returning domain/status data without importing app localization.
- Raw exception messages and arbitrary service-provided English strings are not rendered directly in localized UI.

- [ ] **Step 1: Add localized widget tests for keyboard and account flows**

Test keyboard prompt visibility toggles and metrics in all three locales; test account/delete-dialog labels and cancel behavior; trigger a recoverable action failure and assert that the UI shows a localized generic message rather than the thrown exception text.

- [ ] **Step 2: Run focused tests and verify expected failures**

Run:

```powershell
flutter test test/localization/account_keyboard_localization_test.dart
```

Expected: Chinese labels and sanitized error copy are absent before implementation.

- [ ] **Step 3: Add matching ARB entries for keyboard/account/settings actions**

Cover keyboard practice, prompt mode, labels visibility, accuracy/CPM, optional audio, account state, delete-account confirmation and local-data option, sign-in/out, sync, import/export, empty/invalid import, success states, and every recoverable failure state currently displayed by these pages. Use placeholders for values and keep raw diagnostics out of the message catalog.

- [ ] **Step 4: Localize page copy and map status outcomes at the UI boundary**

Replace literals in the four pages with generated accessors. For sync, switch on the existing `SyncStatus` values (`localOnly`, `pending`, `synced`, `offline`, `error`) to select localized status copy. For auth and import/export failures, show the existing known success/cancel states where identifiable and otherwise use a localized generic failure message that states local progress remains safe. Keep technical diagnostic values out of user-facing text.

- [ ] **Step 5: Regenerate and run account/keyboard/settings tests**

Run:

```powershell
flutter gen-l10n
flutter test test/localization/account_keyboard_localization_test.dart test/task8_widget_test.dart
```

Expected: all three locales render localized actions/errors, and existing deletion/local-data confirmation behavior remains unchanged.

## Task 5: Publish three equivalent READMEs and verify the full localization slice

**Files:**
- Modify: `README.md`
- Create: `README.zh-TW.md`
- Create: `README.en.md`
- Modify: `app/bopomofo/integration_test/offline_learning_test.dart`

**Interfaces:**
- Each README links directly to the other two language entries near its beginning.
- All three files describe the same currently verified setup and verification commands, target platforms, local-first baseline, and external OAuth/Supabase/toolchain limitations.

- [ ] **Step 1: Add the locale-switch progress-preservation integration test**

Use an in-memory locale preference store and the existing in-memory learning repository. Record one review, change from English to each Chinese locale and back, then assert the repository snapshot still contains the review and the translated UI updates. Do not re-bootstrap or replace the repository when locale changes.

- [ ] **Step 2: Run the integration scenario before changing README files**

Run from `app/bopomofo`:

```powershell
flutter test integration_test/offline_learning_test.dart -d windows
```

Expected: the locale-switch scenario passes on the local Windows desktop. CI continues to run its Linux integration path under Xvfb; report either platform as unavailable rather than calling it passed.

- [ ] **Step 3: Verify current README claims and commands against repository files**

Before translating, inspect `tool/verify_workspace.ps1`, `.github/workflows/ci.yml`, `.github/workflows/platform-builds.yml`, `.env.example`, and `app/bopomofo/pubspec.yaml`. Use only commands and claims present in those files and existing platform configuration. Preserve the statement that live OAuth and Supabase behavior requires external setup.

- [ ] **Step 4: Write the three equivalent README entries**

Put Simplified Chinese in `README.md`, Traditional Chinese in `README.zh-TW.md`, and English in `README.en.md`. Add reciprocal language links at the top. Keep headings, command blocks, platform lists, configuration gates, and scope limitations equivalent across the three documents.

- [ ] **Step 5: Run generation, analysis, full app tests, and whitespace checks**

Run from `app/bopomofo`:

```powershell
flutter gen-l10n
flutter analyze
flutter test
flutter test integration_test/offline_learning_test.dart -d linux
```

Then from the repository root run:

```powershell
powershell -ExecutionPolicy Bypass -File tool/verify_workspace.ps1
git diff --check
```

Expected: localization generation, analysis, tests, and whitespace checks pass. Report unavailable device/platform targets as unavailable, not passed.

- [ ] **Step 6: Audit coverage and repository cleanliness**

Search `app/bopomofo/lib` and `packages/design_system/lib` for remaining user-facing English literals, inspect any matches to distinguish identifiers/content from UI copy, and verify all app-owned UI messages have entries in each ARB catalog. Confirm `git status` shows no changed or staged unrelated user files before any commit.

## Final acceptance checklist

- [ ] The app has exactly the three supported locales and uses the approved first-launch policy.
- [ ] A valid saved selection survives restart; invalid or failed preference reads fall back without blocking startup.
- [ ] Preference write failure keeps the current selection active and displays localized non-blocking feedback.
- [ ] All app-owned visible UI and operation states are localized; unknown exception strings are not exposed to users.
- [ ] Language selection does not change auth, sync, or learning state.
- [ ] `README.md`, `README.zh-TW.md`, and `README.en.md` contain equivalent verified content and reciprocal links.
- [ ] Focused tests, full Flutter tests, analysis, integration test where supported, and `git diff --check` have recorded outcomes.
