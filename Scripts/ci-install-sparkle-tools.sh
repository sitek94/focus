#!/usr/bin/env bash
# Download Sparkle release tools matching the project.yml Sparkle pin and put
# generate_appcast / generate_keys / sign_update on PATH for the current job.
#
# Pin: Sparkle 2.9.4 (project.yml packages.Sparkle.revision
# b6496a74a087257ef5e6da1c5b29a447a60f5bd7).
set -euo pipefail

SPARKLE_VERSION="2.9.4"
SPARKLE_TARBALL_URL="https://github.com/sparkle-project/Sparkle/releases/download/${SPARKLE_VERSION}/Sparkle-${SPARKLE_VERSION}.tar.xz"
SPARKLE_TARBALL_SHA256="ce89daf967db1e1893ed3ebd67575ed82d3902563e3191ca92aaec9164fbdef9"

DEST="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/focus-sparkle-tools-${SPARKLE_VERSION}"
ARCHIVE="${DEST}/Sparkle-${SPARKLE_VERSION}.tar.xz"

mkdir -p "$DEST"
if [[ ! -x "${DEST}/bin/generate_appcast" ]]; then
  echo "ci-install-sparkle-tools: downloading Sparkle ${SPARKLE_VERSION} tools"
  curl -fsSL "$SPARKLE_TARBALL_URL" -o "$ARCHIVE"
  actual="$(shasum -a 256 "$ARCHIVE" | awk '{ print $1 }')"
  if [[ "$actual" != "$SPARKLE_TARBALL_SHA256" ]]; then
    echo "error: Sparkle tarball sha256 mismatch" >&2
    echo "  expected: ${SPARKLE_TARBALL_SHA256}" >&2
    echo "  actual:   ${actual}" >&2
    exit 1
  fi
  tar -xJf "$ARCHIVE" -C "$DEST"
fi

if [[ ! -x "${DEST}/bin/generate_appcast" ]]; then
  echo "error: generate_appcast missing after extract at ${DEST}/bin" >&2
  exit 1
fi

echo "${DEST}/bin" >>"${GITHUB_PATH:-/dev/null}"
export PATH="${DEST}/bin:${PATH}"
echo "ci-install-sparkle-tools: generate_appcast=$(command -v generate_appcast)"
