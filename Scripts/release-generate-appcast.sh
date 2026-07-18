#!/usr/bin/env bash
# Run Sparkle 2.9.4 generate_appcast against the final notarized DMG when the
# Ed25519 private key secret is present. Skips otherwise.
# Usage: Scripts/release-generate-appcast.sh <dir-containing-dmg>
set -euo pipefail

ARTIFACT_DIR="${1:-}"
if [[ -z "$ARTIFACT_DIR" || ! -d "$ARTIFACT_DIR" ]]; then
  echo "usage: Scripts/release-generate-appcast.sh <artifact-dir>" >&2
  exit 1
fi

if [[ -z "${SPARKLE_ED25519_PRIVATE_KEY:-}" ]]; then
  echo "release-generate-appcast: SKIP — SPARKLE_ED25519_PRIVATE_KEY unset"
  exit 0
fi

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "error: release-generate-appcast.sh requires macOS" >&2
  exit 1
fi

WORKDIR="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/focus-sparkle-$$"
mkdir -p "$WORKDIR"
KEY_FILE="${WORKDIR}/eddsa-private.pem"
printf '%s\n' "$SPARKLE_ED25519_PRIVATE_KEY" >"$KEY_FILE"
chmod 600 "$KEY_FILE"

GENERATE_APPCAST="$(command -v generate_appcast || true)"
if [[ -z "$GENERATE_APPCAST" ]]; then
  # Resolve from SwiftPM / Sparkle checkout when available later.
  echo "error: generate_appcast not on PATH; install Sparkle 2.9.4 tools before release" >&2
  exit 1
fi

# Minimum system 26.0 / arm64 hardware are documented in docs/sparkle.md;
# generate_appcast flags depend on the installed Sparkle tools version.
"$GENERATE_APPCAST" \
  --ed-key-file "$KEY_FILE" \
  --download-url-prefix "https://github.com/sitek94/focus/releases/latest/download/" \
  "$ARTIFACT_DIR"

if [[ ! -f "${ARTIFACT_DIR}/appcast.xml" ]]; then
  echo "error: appcast.xml was not produced in ${ARTIFACT_DIR}" >&2
  exit 1
fi

echo "release-generate-appcast: wrote ${ARTIFACT_DIR}/appcast.xml"
