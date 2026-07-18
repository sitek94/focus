#!/usr/bin/env bash
# Submit a DMG to notarytool, wait, staple, and validate — when notary secrets exist.
# Usage: Scripts/release-notarize.sh path/to/Focus-VERSION-macos-arm64.dmg
set -euo pipefail

DMG_PATH="${1:-}"
if [[ -z "$DMG_PATH" || ! -f "$DMG_PATH" ]]; then
  echo "usage: Scripts/release-notarize.sh <dmg-path>" >&2
  exit 1
fi

if [[ -z "${APPLE_NOTARY_API_PRIVATE_KEY:-}" ]]; then
  echo "release-notarize: SKIP — APPLE_NOTARY_API_PRIVATE_KEY unset"
  exit 0
fi

for required in APPLE_NOTARY_API_KEY_ID APPLE_NOTARY_API_ISSUER_ID; do
  if [[ -z "${!required:-}" ]]; then
    echo "error: ${required} required when APPLE_NOTARY_API_PRIVATE_KEY is set" >&2
    exit 1
  fi
done

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "error: release-notarize.sh requires macOS" >&2
  exit 1
fi

WORKDIR="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/focus-notary-$$"
mkdir -p "$WORKDIR"
KEY_PATH="${WORKDIR}/AuthKey_${APPLE_NOTARY_API_KEY_ID}.p8"
printf '%s\n' "$APPLE_NOTARY_API_PRIVATE_KEY" >"$KEY_PATH"
chmod 600 "$KEY_PATH"

xcrun notarytool submit "$DMG_PATH" \
  --key "$KEY_PATH" \
  --key-id "$APPLE_NOTARY_API_KEY_ID" \
  --issuer "$APPLE_NOTARY_API_ISSUER_ID" \
  --wait

xcrun stapler staple "$DMG_PATH"
xcrun stapler validate "$DMG_PATH"
spctl --assess --type open --context context:primary-signature -v "$DMG_PATH" || true

echo "release-notarize: stapled and validated ${DMG_PATH}"
