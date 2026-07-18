#!/usr/bin/env bash
# Log Apple toolchain and runner image facts before macOS/iOS CI work.
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "error: log-apple-toolchain.sh requires macOS" >&2
  exit 1
fi

echo "=== Apple toolchain ==="
echo "uname: $(uname -a)"
echo "arch: $(uname -m)"
echo "xcode-select -p: $(xcode-select -p 2>/dev/null || echo '<unavailable>')"
echo "--- xcodebuild -version ---"
xcodebuild -version || true
echo "--- xcodebuild -showsdks ---"
xcodebuild -showsdks || true
echo "--- runner image ---"
if [[ -n "${ImageOS:-}" || -n "${ImageVersion:-}" ]]; then
  echo "ImageOS=${ImageOS:-<unset>}"
  echo "ImageVersion=${ImageVersion:-<unset>}"
fi
if [[ -f /ImageOS ]]; then
  echo "/ImageOS: $(cat /ImageOS)"
fi
if [[ -f "$HOME/hostedtoolcache" ]]; then
  :
fi
# GitHub-hosted macOS images expose version via env and/or plist.
if [[ -n "${RUNNER_NAME:-}" ]]; then
  echo "RUNNER_NAME=${RUNNER_NAME}"
fi
if [[ -n "${RUNNER_OS:-}" ]]; then
  echo "RUNNER_OS=${RUNNER_OS}"
fi
if [[ -n "${RUNNER_ARCH:-}" ]]; then
  echo "RUNNER_ARCH=${RUNNER_ARCH}"
fi
echo "=== end Apple toolchain ==="
