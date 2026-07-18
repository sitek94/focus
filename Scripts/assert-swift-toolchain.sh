#!/usr/bin/env bash
# Assert the Focus-pinned Swift toolchain (6.3.3).
set -euo pipefail

EXPECTED_VERSION="${SWIFT_VERSION:-6.3.3}"

if ! command -v swift >/dev/null 2>&1; then
  echo "error: swift not found on PATH" >&2
  exit 1
fi

version_line="$(swift --version 2>&1 | head -n 1)"
printf 'swift --version: %s\n' "$version_line"

if [[ "$version_line" != *"$EXPECTED_VERSION"* ]]; then
  echo "error: expected Swift ${EXPECTED_VERSION}, got: ${version_line}" >&2
  exit 1
fi

echo "assert-swift-toolchain: ok (${EXPECTED_VERSION})"
