# Task 2 implementation and verification report

Base: `44e60b316b55a4180664af08274b27cb65b8e449`.

## Implementation

- Added a SharedPreferences locale adapter for `app_locale`. It accepts only `zh-Hans`, `zh-Hant`, and `en`; a false `setString` result becomes a write failure.
- The controller falls back to the first device locale policy when a stored tag is absent, invalid, or unreadable. Selection updates listeners before saving and retains the session locale if saving fails.
- Bootstrap loads the controller before normal app dependencies. If SharedPreferences cannot initialize, startup continues with a transient unavailable store.
- `MaterialApp` listens to the controller, installs generated and Flutter localization delegates, and exposes exactly `en`, `zh_Hans`, and `zh_Hant` at runtime. The generated delegate may know the `zh` fallback, but `MaterialApp.supportedLocales` deliberately excludes it.
- The app passes translated navigation labels into the independent design system. Settings offers the native language names and a translated, non-blocking save warning.
- Added `app_zh.arb` as the generator-required base fallback, with the same message keys as the three product catalogs. `appName` remains `Bopomofo`.
- Existing app tests use an explicit English preference fixture; default-locale policy remains in controller tests.

## Changed paths

- `app/bopomofo/lib/localization/shared_preferences_locale_preference_store.dart`
- `app/bopomofo/lib/localization/app_locale_controller.dart`
- `app/bopomofo/lib/bootstrap.dart`
- `app/bopomofo/lib/app.dart`
- `app/bopomofo/lib/features/settings/settings_page.dart`
- `app/bopomofo/lib/l10n/app_en.arb`
- `app/bopomofo/lib/l10n/app_zh.arb`
- `app/bopomofo/lib/l10n/app_zh_Hans.arb`
- `app/bopomofo/lib/l10n/app_zh_Hant.arb`
- `packages/design_system/lib/src/app_scaffold.dart`
- `app/bopomofo/test/localization/app_locale_controller_test.dart`
- `app/bopomofo/test/localization/shared_preferences_locale_preference_store_test.dart`
- `app/bopomofo/test/localization/language_selector_test.dart`
- `app/bopomofo/test/test_support.dart`
- `app/bopomofo/test/smoke_test.dart`
- `app/bopomofo/test/task7_widget_test.dart`
- `app/bopomofo/test/task8_widget_test.dart`
- `app/bopomofo/integration_test/offline_learning_test.dart` (English locale fixture only)
- `.superpowers/sdd/2026-09-23-bopomofo-localization/task-2-report.md`

## Verification

Tests were authored before production edits. The first attempted red run did not execute, so neither red nor green was observed locally.

| Command | Result |
| --- | --- |
| `flutter test test/localization` from `app/bopomofo` | Blocked, exit 1: `flutter : The term 'flutter' is not recognized as the name of a cmdlet, function, script file, or operable program.` |
| `flutter pub get` from `app/bopomofo` | Blocked, exit 1: same PowerShell `flutter` CommandNotFoundException. |
| `flutter test test/localization test/smoke_test.dart test/task7_widget_test.dart test/task8_widget_test.dart` from `app/bopomofo` | Blocked, exit 1: same PowerShell `flutter` CommandNotFoundException. No tests executed. |
| `dart format --output=none --set-exit-if-changed lib test integration_test/offline_learning_test.dart` from `app/bopomofo` | Blocked, exit 1: `dart : The term 'dart' is not recognized as the name of a cmdlet, function, script file, or operable program.` |
| `git diff --check` | Exit 0; Git emitted LF-to-CRLF working-copy warnings, with no whitespace errors. |
| `git diff --cached --check` | Passed, exit 0, no output. |
| PowerShell `ConvertFrom-Json` catalog parity check | Passed, exit 0: all four catalogs have the same ten message keys and `appName=Bopomofo`. The first version of this check used unsupported `-AsHashtable` on the installed PowerShell; it did not validate anything and was rerun using `PSObject.Properties.Name`. |
| PowerShell `ConvertFrom-Json` native-label check | Passed, exit 0: all four catalogs contain exactly `简体中文`, `繁體中文`, and `English`. |
| `git diff --name-only 44e60b316b55a4180664af08274b27cb65b8e449` and `git status --short` | Inspected for scope; changes are limited to the paths above. |

The catalog checks parsed each file as JSON and compared message property names and native labels. They are structural checks; they do not substitute for Flutter's localization generator.

Exact successful PowerShell checks (from the worktree root):

```powershell
$ErrorActionPreference = 'Stop'; $files = Get-ChildItem -LiteralPath 'app/bopomofo/lib/l10n' -Filter '*.arb'; $expected = @('appName','shellTitle','home','dashboard','settings','language','simplifiedChinese','traditionalChinese','english','languageNotSaved'); foreach ($file in $files) { $data = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8 | ConvertFrom-Json; $actual = @($data.PSObject.Properties.Name | Where-Object { $_ -notlike '@*' }); $missing = @($expected | Where-Object { $_ -notin $actual }); $extra = @($actual | Where-Object { $_ -notin $expected }); Write-Output "$($file.Name): locale=$($data.'@@locale') missing=$($missing -join ',') extra=$($extra -join ',') appName=$($data.appName)"; if ($missing.Count -or $extra.Count -or $data.appName -ne 'Bopomofo') { exit 1 } }
$ErrorActionPreference='Stop'; $files=Get-ChildItem -LiteralPath 'app/bopomofo/lib/l10n' -Filter '*.arb'; foreach($file in $files){ $data=Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8 | ConvertFrom-Json; if($data.simplifiedChinese -cne '简体中文' -or $data.traditionalChinese -cne '繁體中文' -or $data.english -cne 'English'){ throw "Native label mismatch in $($file.Name)" }; Write-Output "$($file.Name): native names valid" }
```

### Prior CI finding and ruling

`gh run list --branch feature/bopomofo-localization --limit 5 --json databaseId,status,conclusion,headSha,workflowName,createdAt` showed failed CI run `36308659300` and Platform builds run `36308659271`, both on the pre-Task-2 commit `44e60b3`. `gh run view 36308659300 --log-failed` and `gh run view 36308659271 --log-failed` showed Flutter stable 3.47.5 stopping at `flutter pub get`:

> Generating synthetic localizations package failed with 1 error: Error: Arb file for a fallback, zh, does not exist, even though the following locale(s) exist: [zh_Hans, zh_Hant]. When locales specify a script code or country code, a base locale (without the script code or country code) should exist as the fallback. Please create a {fileName}_zh.arb file.

Both jobs ended with `Process completed with exit code 1`. The ruling is to provide a complete `app_zh.arb` for generation while explicitly restricting runtime supported locales to the three product choices. These prior runs do not validate this Task 2 commit. Flutter generation, compilation, formatting, and tests remain unverified until a runner with Flutter executes them.

## Commit

This report is included in the signed Task 2 commit. The commit hash and post-commit GPG signature verification are provided in the handoff; no push was made.
