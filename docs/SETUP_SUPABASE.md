# Supabase setup

## Database

Create a Supabase project, then link the repository and apply migrations:

```powershell
supabase login
supabase link --project-ref <project-ref>
supabase db push
```

The client needs only the project URL and publishable (formerly anon) key. Never ship a service-role key in the app. Configure `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY` as Flutter compile-time values; local guest mode works when they are absent.

## OAuth

In Supabase Authentication → Providers, enable Google and configure its client credentials and callback URL shown by Supabase. Add the app's platform callback URI to both the provider console and Supabase's allowed redirect URLs. Configure `GOOGLE_OAUTH_REDIRECT_URI` to that exact URI.

For Apple, enable the Apple provider, configure the Services ID/key/team details, associate the iOS/macOS app identifiers and return URL as required by Apple, and allow the app callback in Supabase. Set `APPLE_REDIRECT_URI`; Apple sign-in is exposed only on iOS and macOS. Keep provider secrets in Supabase/provider configuration, not in the client.

The app's OAuth callback is `io.github.williamli0623.bopomofo://login-callback`. Android registers it with an intent filter in `AndroidManifest.xml`, and iOS and macOS register the scheme under `CFBundleURLTypes` in `Info.plist`. Windows and Linux do not register the scheme yet, so CI builds them without Supabase values and they run in guest mode.

### Android native Google sign-in

Android uses the native Google account picker and exchanges its ID token with
Supabase. It does not use the browser/deep-link flow for Google login.

1. In the same Google Cloud project as the Web OAuth client configured in
   Supabase, create an Android OAuth client for package
   `io.github.williamli0623.bopomofo` and the SHA-1 of the certificate signing the
   installed APK. Register debug and release certificates separately when needed.
2. Set the repository secret `GOOGLE_OAUTH_CLIENT_ID` to the **Web** client ID,
   not the Android client ID. This is the audience used for the ID token and
   must match the Google provider configuration in Supabase. No Google client
   secret belongs in the app.
3. Build with `GOOGLE_OAUTH_CLIENT_ID` as well as the Supabase settings below.
   Missing this value fails sign-in with a configuration error; it does not
   silently launch the old Android browser flow.

The Google SDK is initialized once per app process. Its nonce is generated with
secure randomness, hashed for Google, and sent unhashed to Supabase during the
ID-token exchange. Nonce checking must remain enabled. No Google API scopes or
access tokens are requested beyond authentication.

CI reads `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`, and `GOOGLE_OAUTH_REDIRECT_URI` from repository secrets. Android jobs also read `GOOGLE_OAUTH_CLIENT_ID`. `tool/write_dart_defines.sh` turns these into a `--dart-define-from-file` argument for the builds and Android release.

Verify on a physical Android device using the registered signing certificate:
cancel the picker, sign in, confirm the account appears, restart to confirm the
Supabase session persists, then sign out and sign in again. Unit tests cover
the token exchange contract and error paths but do not verify live Google Cloud
or Supabase configuration.

Validate redirect behavior separately for every target platform. This repository does not include production OAuth credentials, provider-console settings, or a deployed Supabase project.

## Account deletion

The authenticated app calls `public.delete_own_account()`. It has no user-id argument: it derives the target from `auth.uid()` and deletes only that Auth identity. Cascading foreign keys remove the associated cloud rows. The client publishable key cannot invoke this function anonymously or for another user. Local data is independently controlled by the in-app confirmation.

The independent deletion instructions are in [`/account/delete`](../web/account-delete/). Review the support contact and deployment details before publishing the page.

## Verification status

Run `supabase db reset` and `supabase test db` locally or in a configured CI job. The repository SQL test covers A/B isolation for all seven user-owned tables and cross-user write attempts. A static inspection is not a substitute for executing these tests against the Supabase Postgres/auth schema. No production credentials are checked in.
