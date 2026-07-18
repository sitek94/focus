#!/usr/bin/env bash
# Ensure the Focus-pinned Xcode (26.6) is the active toolchain.
#
# Resolution order, cheapest/least-invasive first:
#   1. An already-correct DEVELOPER_DIR      (no sudo, no global mutation)
#   2. An already-correct active xcode-select (no sudo, no global mutation)
#   3. Fall back to the pinned bundle path and `sudo xcode-select -s` it.
#
# The pin is the *version* (asserted via `xcodebuild -version`), not a specific
# bundle path. The pinned version lives in `.xcode-version` (sibling of
# `.swift-version`); FOCUS_XCODE_VERSION overrides it. Local Macs usually have
# one `Xcode.app`; CI runners install versioned `Xcode_26.6.app` bundles. Point
# at either via DEVELOPER_DIR or FOCUS_XCODE_APP to avoid the sudo fallback.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION_FILE="${ROOT}/.xcode-version"
if [[ -n "${FOCUS_XCODE_VERSION:-}" ]]; then
  EXPECTED_VERSION="$FOCUS_XCODE_VERSION"
elif [[ -f "$VERSION_FILE" ]]; then
  EXPECTED_VERSION="$(tr -d '[:space:]' <"$VERSION_FILE")"
else
  echo "error: missing ${VERSION_FILE} and FOCUS_XCODE_VERSION unset" >&2
  exit 1
fi

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "error: select-xcode.sh requires macOS" >&2
  exit 1
fi

# Does the developer dir in $1 report the expected Xcode version?
is_expected() {
  local dir="$1"
  [[ -d "$dir" ]] || return 1
  local version
  version="$(DEVELOPER_DIR="$dir" xcodebuild -version 2>/dev/null | head -n 1)" || return 1
  [[ "$version" == "Xcode ${EXPECTED_VERSION}"* ]]
}

report() {
  local dir="$1"
  echo "select-xcode: ${dir}"
  DEVELOPER_DIR="$dir" xcodebuild -version
  if [[ -n "${GITHUB_ENV:-}" ]]; then
    echo "DEVELOPER_DIR=${dir}" >>"$GITHUB_ENV"
  fi
}

# 1. Honor an already-correct DEVELOPER_DIR.
if [[ -n "${DEVELOPER_DIR:-}" ]] && is_expected "$DEVELOPER_DIR"; then
  report "$DEVELOPER_DIR"
  exit 0
fi

# 2. Honor an already-correct active selection.
active="$(xcode-select -p 2>/dev/null || true)"
if [[ -n "$active" ]] && is_expected "$active"; then
  report "$active"
  exit 0
fi

# 3. Fall back to the pinned bundle path (requires sudo to switch globally).
XCODE_APP="${FOCUS_XCODE_APP:-/Applications/Xcode_${EXPECTED_VERSION}.app}"
XCODE_DEVELOPER="${FOCUS_XCODE_DEVELOPER:-${XCODE_APP}/Contents/Developer}"

if ! is_expected "$XCODE_DEVELOPER"; then
  echo "error: could not find Xcode ${EXPECTED_VERSION}" >&2
  echo "  DEVELOPER_DIR=${DEVELOPER_DIR:-<unset>}" >&2
  echo "  active xcode-select=${active:-<none>}" >&2
  echo "  fallback path=${XCODE_DEVELOPER}" >&2
  echo "available Xcode.app bundles:" >&2
  ls -1d /Applications/Xcode*.app 2>/dev/null || true
  echo "hint: export DEVELOPER_DIR=/path/to/Xcode.app/Contents/Developer to skip sudo" >&2
  exit 1
fi

sudo xcode-select -s "$XCODE_DEVELOPER"
report "$XCODE_DEVELOPER"
