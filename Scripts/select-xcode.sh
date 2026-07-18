#!/usr/bin/env bash
# Select the Focus-pinned Xcode 26.6 developer directory.
set -euo pipefail

XCODE_APP="${FOCUS_XCODE_APP:-/Applications/Xcode_26.6.app}"
XCODE_DEVELOPER="${FOCUS_XCODE_DEVELOPER:-${XCODE_APP}/Contents/Developer}"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "error: select-xcode.sh requires macOS" >&2
  exit 1
fi

if [[ ! -d "$XCODE_DEVELOPER" ]]; then
  echo "error: expected Xcode at ${XCODE_DEVELOPER}" >&2
  echo "available Xcode.app bundles:" >&2
  ls -1d /Applications/Xcode*.app 2>/dev/null || true
  exit 1
fi

sudo xcode-select -s "$XCODE_DEVELOPER"
export DEVELOPER_DIR="$XCODE_DEVELOPER"

if [[ -n "${GITHUB_ENV:-}" ]]; then
  echo "DEVELOPER_DIR=${XCODE_DEVELOPER}" >>"$GITHUB_ENV"
fi

selected="$(xcode-select -p)"
if [[ "$selected" != "$XCODE_DEVELOPER" ]]; then
  echo "error: xcode-select -p is '${selected}', expected '${XCODE_DEVELOPER}'" >&2
  exit 1
fi

version="$(xcodebuild -version | tr '\n' ' ')"
if [[ "$version" != Xcode\ 26.6* ]]; then
  echo "error: expected Xcode 26.6, got: ${version}" >&2
  exit 1
fi

echo "select-xcode: ${selected}"
xcodebuild -version
