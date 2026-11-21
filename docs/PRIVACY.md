# Privacy

Last updated: 2026-11-21

Bopomofo is designed local-first. Learning works without an account or network connection. Review events and derived progress are stored in the app's local SQLite database. Signing in is optional; when a signed-in user enables cloud sync, the app sends learning events and sync metadata to the configured Supabase project.

The app contains no analytics, telemetry, advertising, or crash reporting. Listening-exercise audio is bundled at build time from the Ministry of Digital Affairs' CNS11643 open-data archive; it is never fetched from the network and carries no personal data.

## Data

The service may process an authentication identifier and provider account attributes, profile display name/avatar when available, device identifier/platform/app version, learning events (item, skill, correctness, response, timing and hint/retry counts), derived review/confusion snapshots, user settings, and sync cursor/state. OAuth authentication is handled by the configured identity provider and Supabase Auth. The app does not request location, contacts, or advertising identifiers and does not include ad tracking.

## Storage, sharing, and retention

Local learning data remains on the device until the user clears app data or uninstalls the app. Cloud data is stored in the project operator's Supabase region and is accessible to the account owner through row-level security. The app does not sell learning data or use it for advertising. Operators with authorized database access may process it to operate, secure, troubleshoot, and improve the service.

Synced account data is retained until account deletion or project retention changes. Account deletion removes the Supabase Auth identity; database foreign-key cascades remove its profile, devices, learning events, snapshots, confusion data, settings, and sync state. Local data is separate and requires the explicit local-data option in the app. Backups may persist until the provider's backup-retention window expires.

## Your choices

You can use guest mode, export learning data, sign out, and request cloud-account deletion. In-app deletion is available at Settings → Account. If you cannot access the app, use the instructions at [`/account/delete`](../web/account-delete/). Deletion is irreversible. Do not email passwords; the operator must verify ownership using the account email.

## Configuration and contact

The account-deletion page lists xuanming.li0623@gmail.com as its support contact. Before publishing, the operator must still add its legal identity, Supabase region/retention details, and any jurisdiction-specific disclosures. OAuth providers receive data according to their own policies.

See [`SETUP_SUPABASE.md`](SETUP_SUPABASE.md) for self-hosted/project configuration. This notice describes the repository implementation, not a guarantee about a separately deployed instance.
