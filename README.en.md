# Bopomofo

[简体中文](README.md) | [繁體中文](README.zh-TW.md) | English

Bopomofo is a local-first app for learning Bopomofo from what you already know. It targets Android, iOS, Windows, macOS, and Linux; guest mode keeps learning progress on the device.

## Requirements

- Dart SDK: `>=3.6.0 <4.0.0`
- Flutter SDK: `>=3.27.0`
- The app UI supports Simplified Chinese (`zh-Hans`), Traditional Chinese (`zh-Hant`), and English (`en`).
- Native builds require the matching platform toolchain. GitHub Actions builds Linux, Android, and Windows; macOS and iOS builds run through a manually dispatched workflow, with iOS using `--no-codesign`.

## Installation

From the repository root, run:

```text
dart pub get
```

From `app/bopomofo`, run:

```text
flutter pub get
```

## Configuration

Guest mode and local learning need no Supabase or OAuth credentials. Connecting live services requires an external Supabase project, OAuth provider setup, and platform callback, redirect, and signing configuration. The environment variable template is `.env.example`: `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`, `GOOGLE_OAUTH_CLIENT_ID`, `GOOGLE_OAUTH_REDIRECT_URI`, `APPLE_SERVICE_ID`, and `APPLE_REDIRECT_URI`. The template contains no credentials.

## Quick start

From `app/bopomofo`, start the Windows desktop app:

```text
flutter run -d windows
```

## Verification

From `app/bopomofo`, generate localization files, run analysis, and test the app:

```text
flutter gen-l10n
flutter analyze
flutter test
```

Run the offline integration test on Windows:

```text
flutter test integration_test/offline_learning_test.dart -d windows
```

Linux CI runs the same integration test in Xvfb:

```text
xvfb-run -a flutter test integration_test/offline_learning_test.dart -d linux
```

From the repository root, run the workspace verification script:

```text
powershell -ExecutionPolicy Bypass -File tool/verify_workspace.ps1
```

The local baseline tests do not require live Supabase or OAuth services. Connecting live services and deleting a real account require the corresponding external setup.
