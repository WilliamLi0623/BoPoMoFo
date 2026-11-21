# Windows and Linux desktop builds

## Windows

1. Download `BoPoMoFo-<version>-windows-x64.zip` from a release and unpack it.
2. Optional, once per unpacked copy: register the OAuth callback so Google
   sign-in can return to the app.
   `powershell -ExecutionPolicy Bypass -File .\register_windows_protocol.ps1`
   The script writes the `io.github.williamli0623.bopomofo://` URL protocol
   under `HKCU` for that unpacked exe (see
   `tool/register_windows_protocol.ps1`).
3. Sign in from Settings → *Sign in with Google*. The browser completes the
   Google consent and hands the redirect back to the app. Without the
   registration the app stays in guest mode and progress is kept on the
   device.

Windows builds run on the self-hosted `bopomofo-windows` runner. The
`windows-latest` hosted jobs are blocked by the account's GitHub Actions
spending limit until billing is fixed; the self-hosted runner keeps the
pipeline green in the meantime.

## Linux

The `.deb` and `.tar.gz` builds run in guest mode. `app_links` has no Linux
implementation yet, so the OAuth callback scheme is not registered there and
sign-in is intentionally unavailable; Linux builds carry no Supabase values.
Wiring Linux deep links requires a custom URL handler in `linux/runner`
before sign-in can ship.

## Privacy

See [docs/PRIVACY.md](PRIVACY.md) (and `docs/PRIVACY.zh-Hant.md`) for what is
stored on the device, what syncs to the cloud, and how deletion works.
