#!/usr/bin/env bash
# Writes the client-side Supabase/OAuth values that are set in the environment
# to a dart-define file outside the workspace and exports DART_DEFINES_ARG for
# later steps. Unset or empty values are skipped, so a build without them stays
# in guest mode. Only publishable client values belong here, never a
# service-role or secret key.
set -euo pipefail

file="${RUNNER_TEMP:-/tmp}/dart_defines.env"
: > "$file"
count=0
for name in SUPABASE_URL SUPABASE_PUBLISHABLE_KEY GOOGLE_OAUTH_REDIRECT_URI APPLE_REDIRECT_URI; do
  value="${!name:-}"
  if [[ -n "$value" ]]; then
    printf '%s=%s\n' "$name" "$value" >> "$file"
    count=$((count + 1))
  fi
done

if [[ "$count" -eq 0 ]]; then
  echo 'No Supabase/OAuth values set; building in guest mode.'
  rm -f "$file"
  exit 0
fi

echo "Wrote $count dart-define value(s)."
if [[ -n "${GITHUB_ENV:-}" ]]; then
  echo "DART_DEFINES_ARG=--dart-define-from-file=$file" >> "$GITHUB_ENV"
fi
