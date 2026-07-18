#!/usr/bin/env bash
# Archive/export arm64 Focus.app for release when signing is available.
# Without signing secrets, performs the same unsigned structural archive as CI
# and skips DMG/export (documented skip — not a silent success for publishing).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

VERSION="${1:-}"
if [[ -z "$VERSION" ]]; then
  echo "usage: Scripts/release-archive-export.sh <X.Y.Z>" >&2
  exit 1
fi

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "error: release-archive-export.sh requires macOS" >&2
  exit 1
fi

mkdir -p build/release
ARCHIVE_PATH="build/release/Focus.xcarchive"
EXPORT_DIR="build/release/export"
DMG_PATH="build/release/Focus-${VERSION}-macos-arm64.dmg"

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

xcodebuild \
  -project Focus.xcodeproj \
  -scheme FocusMac \
  -destination "generic/platform=macOS" \
  -archivePath "$ARCHIVE_PATH" \
  archive

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
