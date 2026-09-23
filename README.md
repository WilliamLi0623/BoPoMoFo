# Bopomofo

Learn Bopomofo from what you already know.

Bopomofo targets Android, iOS, Windows, macOS, and Linux. The initial shell
starts in guest mode and keeps the learning entry point local-first. It does
not create an authenticated session without configured authentication.

## Baseline commands

```text
flutter pub get
flutter test
flutter analyze
flutter run -d windows
```

For workspace-wide verification, run `./tool/verify_workspace.ps1` from
PowerShell. GitHub Actions also runs Dart package tests, app analysis, Flutter
tests, offline/restart and multi-device merge integration scenarios, plus
native platform builds on matching operating-system runners.

These commands exercise the local shell and do not require Supabase or OAuth
credentials. Supabase sync, Google OAuth, Apple OAuth, and account deletion
against a live project are configuration-gated and require the corresponding
values from `.env.example`, provider setup, and platform redirect/signing
configuration. The baseline smoke test must remain runnable without them.

## Scope limits

This slice does not add AI, ads, location, contacts, leaderboards, or cloud
audio-cache features.
