# Bopomofo Localization Design

Date: 2026-09-23

Status: Draft for user review

Decision: Approved direction; detailed specification pending review

## Goal

Make the Bopomofo app usable in Simplified Chinese, Traditional Chinese, and English, with Chinese as the default. Present the root README in Simplified Chinese and provide separate Traditional Chinese and English entries. Preserve the existing learning, account, and offline behavior while changing locale.

## Approved decisions

- Use Flutter's built-in `gen_l10n` localization generation with ARB resource files.
- Support `zh_Hans`, `zh_Hant`, and `en` as distinct locales.
- On first launch, follow the device's selected Chinese locale when it is Chinese. Resolve `zh-Hant` and the Traditional Chinese regions (TW, HK, MO) to Traditional Chinese; resolve `zh-Hans` and Simplified Chinese regions (CN, SG) to Simplified Chinese. If the selected device locale is not Chinese, default to Simplified Chinese.
- Let the user choose any of the three languages in Settings. A manual selection is persisted locally and takes precedence over the device locale on later launches.
- Use `README.md` for Simplified Chinese, with direct links to `README.zh-TW.md` and `README.en.md`.

## Approaches considered

1. **Flutter `gen_l10n` and ARB (selected).** Uses Flutter's supported localization generation and locale-aware plural/message formatting, provides typed generated accessors, and avoids adding a third-party localization runtime. The trade-off is a generated localization setup and the need to keep three ARB catalogs in sync.
2. **A third-party localization package.** May provide additional runtime conveniences, but adds a dependency and another source of locale behavior without a current need in this app.
3. **Manual string maps.** Has low initial setup cost, but loses generated key checking and makes pluralization, interpolation, and translator consistency easier to get wrong.

## Architecture and boundaries

- Configure Flutter localization generation in `app/bopomofo`; keep source catalogs in that app and generated localization code in the app's generated-source location. Commit the ARB catalogs and generator configuration, not hand-maintained duplicate maps.
- Add the Flutter localization delegates and the three supported script-specific locales to `MaterialApp`. Keep the product name `Bopomofo` unchanged.
- Add a small app-owned locale preference/controller boundary. It loads an optional explicit locale before `runApp`, resolves the first-launch default from the platform locale, updates the running `MaterialApp` when the user changes language, and persists only explicit user choices.
- Put `shared_preferences` in app runtime dependencies for the language preference; it remains device-local and is not added to learning-data export, account sync, or the domain model.
- Keep `packages/design_system` independent of app localization. Change its shared scaffold API to receive localized navigation labels from the app rather than importing generated app localization classes.
- Add a language selector to Settings, displaying native names (简体中文, 繁體中文, English). Changing it takes effect immediately and survives app restart.
- Translate all app-owned user-facing text in the onboarding, lesson, review, dashboard, keyboard, settings, account/deletion, and shared navigation surfaces. This includes action labels, accessibility labels, status/empty/offline states, and interpolated counts. Keep Bopomofo symbols, user email addresses, product names, and technical acronyms such as CPM unchanged where they are content rather than UI prose.
- Do not display raw exception strings as user-facing copy. Map known error/status types to localized messages; show a localized generic recovery message for unknown failures while preserving diagnostic details only in logs or non-user-facing diagnostics.

## README content

- Rewrite the root `README.md` in Simplified Chinese while preserving only claims and commands verified against the current repository.
- Add `README.zh-TW.md` and `README.en.md` as faithful Traditional Chinese and English versions of the same project overview, setup instructions, verification commands, platform scope, and configuration limitations.
- Put the three language links near the top of each README. Do not translate unrelated package-level scaffold READMEs as part of this change.

## Behavior and failure handling

- If no saved choice exists, resolve the platform-selected locale using the approved Chinese script/region policy; all non-Chinese locales fall back to Simplified Chinese.
- A valid saved choice always wins over device settings. Invalid or absent stored values fall back to device resolution.
- A preference read failure must not block startup; use the device-derived default. If saving a new selection fails, apply it for the current session and show localized, non-blocking feedback that the choice may not persist.
- Changing language must not recreate or clear the learning repository, sign the user out, alter sync state, or discard unsaved learning progress.
- Generated messages must use locale-aware interpolation/plural rules rather than concatenating English fragments.

## Scope exclusions

- No new language, translation service, remote localization downloads, or user-generated content translation.
- No change to learning algorithms, curricula, persistence schema, authentication, sync protocol, or platform support.
- No rewrite of package-specific READMEs beyond the root language entry points described above.

## Verification and acceptance criteria

1. Localization generation and Flutter analysis pass with all three ARB catalogs valid and no untranslated app-owned strings left in the targeted UI.
2. Locale-resolution unit tests cover explicit Hans/Hant scripts, CN/SG and TW/HK/MO regions, ambiguous Chinese locale, non-Chinese locale, and locale-list behavior.
3. Preference tests cover no saved choice, each saved language, invalid stored values, persistence failure, and restart/reload behavior.
4. Widget tests verify the language selector is reachable, labels change immediately for all three locales, and the selected language remains after reconstructing the app with the same preference store.
5. Existing widget and integration tests continue to pass; add a locale-switch regression assertion that the currently recorded learning progress remains intact.
6. Review all three README files for equivalent commands, links, platform claims, and clearly stated external credential/toolchain limits.
7. Run the repository's relevant Flutter test and verification commands. Report platform-specific unavailable checks separately; do not claim them as passing.

## Review boundary

This document is the localization design for user review. Implementation planning and code changes begin only after the user approves this written specification.
