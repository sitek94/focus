#!/usr/bin/env bash
# Import Developer ID Application identity into a temporary keychain when secrets exist.
# Skips cleanly when APPLE_DEVELOPER_ID_APPLICATION_P12_BASE64 is unset.
set -euo pipefail

if [[ -z "${APPLE_DEVELOPER_ID_APPLICATION_P12_BASE64:-}" ]]; then
  echo "release-import-signing: SKIP — APPLE_DEVELOPER_ID_APPLICATION_P12_BASE64 unset"
  echo "FOCUS_SIGNING_AVAILABLE=0"
  if [[ -n "${GITHUB_ENV:-}" ]]; then
    echo "FOCUS_SIGNING_AVAILABLE=0" >>"$GITHUB_ENV"
  fi
  exit 0
fi

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "error: release-import-signing.sh requires macOS" >&2
  exit 1
fi

WORKDIR="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/focus-signing-$$"
mkdir -p "$WORKDIR"
P12_PATH="${WORKDIR}/developer-id.p12"
KEYCHAIN_PATH="${WORKDIR}/focus-release.keychain-db"
KEYCHAIN_PASSWORD="$(openssl rand -base64 32)"

echo "${APPLE_DEVELOPER_ID_APPLICATION_P12_BASE64}" | base64 --decode >"$P12_PATH"

security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
security set-keychain-settings -lut 21600 "$KEYCHAIN_PATH"
security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
# Password may be empty — Keychain Access allows exporting a .p12 with no passphrase.
security import "$P12_PATH" \
  -k "$KEYCHAIN_PATH" \
  -P "${APPLE_DEVELOPER_ID_APPLICATION_P12_PASSWORD:-}" \
  -T /usr/bin/codesign \
  -T /usr/bin/security \
  -T /usr/bin/productbuild
security set-key-partition-list \
  -S apple-tool:,apple:,codesign: \
  -s \
  -k "$KEYCHAIN_PASSWORD" \
  "$KEYCHAIN_PATH"
security list-keychains -d user -s "$KEYCHAIN_PATH" $(security list-keychains -d user | sed -e 's/"//g')

echo "FOCUS_SIGNING_AVAILABLE=1"
echo "FOCUS_KEYCHAIN_PATH=${KEYCHAIN_PATH}"
if [[ -n "${GITHUB_ENV:-}" ]]; then
  {
    echo "FOCUS_SIGNING_AVAILABLE=1"
    echo "FOCUS_KEYCHAIN_PATH=${KEYCHAIN_PATH}"
  } >>"$GITHUB_ENV"
fi

echo "release-import-signing: imported Developer ID identity into temporary keychain"
