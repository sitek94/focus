#!/usr/bin/env bash
# Structural unsigned macOS archive for PR CI, with project-format warning gate.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "error: archive-macos-ci.sh requires macOS" >&2
  exit 1
fi

if [[ ! -d Focus.xcodeproj ]]; then
  echo "error: Focus.xcodeproj missing; run make generate-project first" >&2
  exit 1
fi

mkdir -p build
LOG="build/archive-macos-ci.log"
ARCHIVE_PATH="build/Focus.xcarchive"

rm -rf "$ARCHIVE_PATH"

set +e
xcodebuild \
  -project Focus.xcodeproj \
  -scheme FocusMac \
  -destination "generic/platform=macOS" \
  -archivePath "$ARCHIVE_PATH" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGN_IDENTITY="" \
  archive 2>&1 | tee "$LOG"
status=${PIPESTATUS[0]}
set -e

if [[ "$status" -ne 0 ]]; then
  echo "error: unsigned archive failed (exit ${status}); see ${LOG}" >&2
  exit "$status"
fi

# Fail on Xcode project-format upgrade / migration warnings (A33 / PLAN §14).
if grep -Eiq \
  'upgrade.*(project|pbxproj)|project format|objectVersion|Migrate.*project|Update to recommended settings' \
  "$LOG"; then
  echo "error: archive log contains project-format / migration warnings:" >&2
  grep -Ei \
    'upgrade.*(project|pbxproj)|project format|objectVersion|Migrate.*project|Update to recommended settings' \
    "$LOG" >&2 || true
  exit 1
fi

if [[ ! -d "$ARCHIVE_PATH" ]]; then
  echo "error: archive path missing after success: ${ARCHIVE_PATH}" >&2
  exit 1
fi

echo "archive-macos-ci: ok (${ARCHIVE_PATH})"
