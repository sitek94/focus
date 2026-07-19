#!/usr/bin/env bash
# Archive/export arm64 Focus.app for release when signing is available.
# Without signing secrets, performs the same unsigned structural archive as CI
# and skips DMG/export (documented skip — not a silent success for publishing).
#
# Usage: Scripts/release-archive-export.sh <marketing-version> [build-number]
# Environment overrides applied to xcodebuild when set:
#   CURRENT_PROJECT_VERSION, MARKETING_VERSION, FOCUS_GIT_COMMIT
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

MARKETING_VERSION="${1:-}"
BUILD_NUMBER="${2:-${CURRENT_PROJECT_VERSION:-}}"
if [[ -z "$MARKETING_VERSION" ]]; then
  echo "usage: Scripts/release-archive-export.sh <X.Y.Z> [build-number]" >&2
  exit 1
fi

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "error: release-archive-export.sh requires macOS" >&2
  exit 1
fi

if [[ -z "$BUILD_NUMBER" ]]; then
  BUILD_NUMBER="$(
    awk -F' *= *' '/^CURRENT_PROJECT_VERSION/ { print $2; exit }' Config/Shared.xcconfig
  )"
fi
if [[ -z "$BUILD_NUMBER" ]]; then
  echo "error: build number missing (pass arg 2 or set CURRENT_PROJECT_VERSION)" >&2
  exit 1
fi

mkdir -p build/release
ARCHIVE_PATH="build/release/Focus.xcarchive"
EXPORT_DIR="build/release/export"
DMG_PATH="build/release/Focus-${MARKETING_VERSION}.${BUILD_NUMBER}-macos-arm64.dmg"

rm -rf "$ARCHIVE_PATH" "$EXPORT_DIR" "$DMG_PATH"

if [[ "${FOCUS_SIGNING_AVAILABLE:-0}" != "1" ]]; then
  echo "release-archive-export: signing unavailable — structural unsigned archive only"
  ./Scripts/archive-macos-ci.sh
  mkdir -p build/release
  if [[ -d build/Focus.xcarchive ]]; then
    rm -rf "$ARCHIVE_PATH"
    mv build/Focus.xcarchive "$ARCHIVE_PATH"
  fi
  echo "FOCUS_RELEASE_DMG="
  if [[ -n "${GITHUB_ENV:-}" ]]; then
    echo "FOCUS_RELEASE_DMG=" >>"$GITHUB_ENV"
  fi
  echo "release-archive-export: SKIP DMG/export (no Developer ID secrets)"
  exit 0
fi

if [[ -z "${APPLE_TEAM_ID:-}" ]]; then
  echo "error: APPLE_TEAM_ID required when signing is available" >&2
  exit 1
fi

# Substitute team ID into a temporary ExportOptions plist.
EXPORT_PLIST="build/release/ExportOptions.plist"
sed "s/\$(APPLE_TEAM_ID)/${APPLE_TEAM_ID}/g" Config/ExportOptions.plist >"$EXPORT_PLIST"

xcodebuild_args=(
  -project Focus.xcodeproj
  -scheme FocusMac
  -destination "generic/platform=macOS"
  -archivePath "$ARCHIVE_PATH"
  MARKETING_VERSION="${MARKETING_VERSION}"
  CURRENT_PROJECT_VERSION="${BUILD_NUMBER}"
  CODE_SIGN_STYLE=Manual
  CODE_SIGN_IDENTITY="Developer ID Application"
  DEVELOPMENT_TEAM="${APPLE_TEAM_ID}"
  OTHER_CODE_SIGN_FLAGS="--timestamp"
)
if [[ -n "${FOCUS_GIT_COMMIT:-}" ]]; then
  xcodebuild_args+=("FOCUS_GIT_COMMIT=${FOCUS_GIT_COMMIT}")
fi

xcodebuild "${xcodebuild_args[@]}" archive

xcodebuild \
  -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_DIR" \
  -exportOptionsPlist "$EXPORT_PLIST"

APP_PATH="${EXPORT_DIR}/Focus.app"
if [[ ! -d "$APP_PATH" ]]; then
  echo "error: exported Focus.app missing at ${APP_PATH}" >&2
  exit 1
fi

codesign --verify --deep --strict --verbose=2 "$APP_PATH"
# Fail closed if we somehow still got an ad-hoc / local signature.
signing_info="$(codesign -dv --verbose=2 "$APP_PATH" 2>&1 || true)"
echo "$signing_info"
if ! grep -Fq "Authority=Developer ID Application" <<<"$signing_info"; then
  echo "error: Focus.app is not Developer ID Application signed" >&2
  exit 1
fi
if grep -Eq 'Signature=adhoc|Authority=Sign to Run Locally' <<<"$signing_info"; then
  echo "error: Focus.app still has an ad-hoc / local signature" >&2
  exit 1
fi

# Minimal DMG packaging; refined layout can land with Sparkle app wiring.
hdiutil create \
  -volname "Focus" \
  -srcfolder "$APP_PATH" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

codesign --force --sign "Developer ID Application" "$DMG_PATH" || true

echo "FOCUS_RELEASE_DMG=${DMG_PATH}"
if [[ -n "${GITHUB_ENV:-}" ]]; then
  echo "FOCUS_RELEASE_DMG=${DMG_PATH}" >>"$GITHUB_ENV"
fi
echo "release-archive-export: wrote ${DMG_PATH}"
