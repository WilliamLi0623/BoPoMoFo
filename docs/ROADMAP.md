# Roadmap

The checked-in product foundation includes guest-first offline learning, local event replay, review scheduling, keyboard practice, optional Supabase event sync, export/import, and account/data-deletion flows.

Remaining work before a public release:

- Hosted CI runs package, Flutter, and Linux integration tests, plus debug builds for all five platforms (iOS without code signing). Still open: signed iOS/macOS release builds and integration tests on macOS, iOS, Android, and Windows runners.
- Configure and test Google OAuth on supported targets and Apple OAuth on iOS/macOS.
- Publish the privacy notice with the operator's legal identity, Supabase region/retention details, and jurisdiction-specific disclosures.
- Add operational monitoring, backup/restore exercises, and a documented support/deletion SLA.
- Validate accessibility, localization, curriculum accuracy, and store-release requirements with users and domain reviewers.

No claim of production readiness or live-provider verification is made by this repository plan.
