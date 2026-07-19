#!/usr/bin/env bash
# Archive FocusIOS with App Store Connect API auth and upload to TestFlight.
# Usage: Scripts/release-ios-archive-upload.sh <marketing-version> <build-number>
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

MARKETING_VERSION="${1:-}"
BUILD_NUMBER="${2:-${CURRENT_PROJECT_VERSION:-}}"
if [[ -z "$MARKETING_VERSION" || -z "$BUILD_NUMBER" ]]; then
  echo "usage: Scripts/release-ios-archive-upload.sh <X.Y.Z> <build-number>" >&2
  exit 1
fi

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "error: release-ios-archive-upload.sh requires macOS" >&2
  exit 1
fi

for required in APPLE_TEAM_ID APPLE_NOTARY_API_PRIVATE_KEY APPLE_NOTARY_API_KEY_ID APPLE_NOTARY_API_ISSUER_ID; do
  if [[ -z "${!required:-}" ]]; then
    echo "error: ${required} required for iOS deploy" >&2
    exit 1
  fi
done

mkdir -p build/release
ARCHIVE_PATH="build/release/FocusIOS.xcarchive"
EXPORT_DIR="build/release/ios-export"
EXPORT_PLIST="build/release/ExportOptionsIOS.plist"
rm -rf "$ARCHIVE_PATH" "$EXPORT_DIR"
sed "s/\$(APPLE_TEAM_ID)/${APPLE_TEAM_ID}/g" Config/ExportOptionsIOS.plist >"$EXPORT_PLIST"

WORKDIR="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/focus-ios-auth-$$"
mkdir -p "$WORKDIR"
KEY_PATH="${WORKDIR}/AuthKey_${APPLE_NOTARY_API_KEY_ID}.p8"
printf '%s\n' "$APPLE_NOTARY_API_PRIVATE_KEY" >"$KEY_PATH"
chmod 600 "$KEY_PATH"

auth_args=(
  -allowProvisioningUpdates
  -authenticationKeyPath "$KEY_PATH"
  -authenticationKeyID "$APPLE_NOTARY_API_KEY_ID"
  -authenticationKeyIssuerID "$APPLE_NOTARY_API_ISSUER_ID"
)

xcodebuild_args=(
  -project Focus.xcodeproj
  -scheme FocusIOS
  -destination "generic/platform=iOS"
  -archivePath "$ARCHIVE_PATH"
  MARKETING_VERSION="${MARKETING_VERSION}"
  CURRENT_PROJECT_VERSION="${BUILD_NUMBER}"
  DEVELOPMENT_TEAM="${APPLE_TEAM_ID}"
  CODE_SIGN_STYLE=Automatic
)
if [[ -n "${FOCUS_GIT_COMMIT:-}" ]]; then
  xcodebuild_args+=("FOCUS_GIT_COMMIT=${FOCUS_GIT_COMMIT}")
fi

echo "release-ios: archiving FocusIOS ${MARKETING_VERSION} (${BUILD_NUMBER})"
xcodebuild "${xcodebuild_args[@]}" "${auth_args[@]}" archive

echo "release-ios: uploading archive to App Store Connect / TestFlight"
xcodebuild \
  -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_DIR" \
  -exportOptionsPlist "$EXPORT_PLIST" \
  "${auth_args[@]}"

echo "release-ios: upload complete"
