#!/usr/bin/env bash
# Install the Focus-pinned Swift toolchain on Ubuntu via swiftly (no caches).
# Intended for GitHub Actions ubuntu-24.04 runners.
set -euo pipefail

SWIFT_VERSION="${SWIFT_VERSION:-6.3.3}"
SWIFTLY_VERSION="${SWIFTLY_VERSION:-1.1.3}"
SWIFTLY_SIGNING_FINGERPRINT="${SWIFTLY_SIGNING_FINGERPRINT:-E813C892820A6FA13755B268F167DF1ACF9CE069}"

if [[ "$(uname -s)" != "Linux" ]]; then
  echo "error: ci-install-swift-linux.sh is Linux-only" >&2
  exit 1
fi

missing_packages=()
for package in ca-certificates curl gpg libcurl4-openssl-dev libsqlite3-dev pkg-config; do
  if ! dpkg-query -W -f='${Status}' "$package" 2>/dev/null | grep -q "install ok installed"; then
    missing_packages+=("$package")
  fi
done
if [[ "${#missing_packages[@]}" -gt 0 ]]; then
  sudo apt-get update
  sudo apt-get install -y "${missing_packages[@]}"
fi

if command -v swift >/dev/null 2>&1; then
  if swift --version 2>&1 | head -n 1 | grep -Fq "$SWIFT_VERSION"; then
    echo "ci-install-swift-linux: Swift ${SWIFT_VERSION} already present"
    exit 0
  fi
fi

SWIFTLY_ARCH="$(uname -m)"
WORKDIR="${RUNNER_TEMP:-${TMPDIR:-/tmp}}"
SWIFTLY_ARCHIVE="${WORKDIR}/swiftly-${SWIFTLY_VERSION}-${SWIFTLY_ARCH}.tar.gz"
SWIFTLY_SIGNATURE="${SWIFTLY_ARCHIVE}.sig"
SWIFTLY_HOME_DIR="${SWIFTLY_HOME_DIR:-$HOME/.local/share/swiftly}"
SWIFTLY_BIN_DIR="${SWIFTLY_BIN_DIR:-$HOME/.local/bin}"
SWIFT_GNUPGHOME="$(mktemp -d)"
SWIFT_KEYS="${WORKDIR}/swift-signing-keys.asc"
POST_INSTALL_SCRIPT="$(mktemp)"

cleanup() {
  rm -rf "$SWIFT_GNUPGHOME"
}
trap cleanup EXIT

mkdir -p "$SWIFTLY_BIN_DIR"
chmod 700 "$SWIFT_GNUPGHOME"

curl -fsSL "https://download.swift.org/swiftly/linux/swiftly-${SWIFTLY_VERSION}-${SWIFTLY_ARCH}.tar.gz" -o "$SWIFTLY_ARCHIVE"
curl -fsSL "https://download.swift.org/swiftly/linux/swiftly-${SWIFTLY_VERSION}-${SWIFTLY_ARCH}.tar.gz.sig" -o "$SWIFTLY_SIGNATURE"
curl -fsSL --compressed "https://www.swift.org/keys/all-keys.asc" -o "$SWIFT_KEYS"

GNUPGHOME="$SWIFT_GNUPGHOME" gpg --batch --import "$SWIFT_KEYS"
SIGNATURE_STATUS="$(
  GNUPGHOME="$SWIFT_GNUPGHOME" gpg --batch --status-fd=1 \
    --verify "$SWIFTLY_SIGNATURE" "$SWIFTLY_ARCHIVE" 2>&1
)"
printf '%s\n' "$SIGNATURE_STATUS"
grep -Fq "[GNUPG:] VALIDSIG ${SWIFTLY_SIGNING_FINGERPRINT} " <<<"$SIGNATURE_STATUS"

tar -xzf "$SWIFTLY_ARCHIVE" -C /tmp
/tmp/swiftly init --assume-yes --skip-install

# shellcheck source=/dev/null
. "$SWIFTLY_HOME_DIR/env.sh"

if [[ -n "${GITHUB_PATH:-}" ]]; then
  echo "$SWIFTLY_BIN_DIR" >>"$GITHUB_PATH"
fi
if [[ -n "${GITHUB_ENV:-}" ]]; then
  {
    echo "SWIFTLY_HOME_DIR=$SWIFTLY_HOME_DIR"
    echo "SWIFTLY_BIN_DIR=$SWIFTLY_BIN_DIR"
  } >>"$GITHUB_ENV"
fi

export PATH="$SWIFTLY_BIN_DIR:$PATH"
swiftly install "$SWIFT_VERSION" --use --assume-yes --verify --post-install-file "$POST_INSTALL_SCRIPT"
if [[ -s "$POST_INSTALL_SCRIPT" ]]; then
  sudo apt-get update
  sudo bash "$POST_INSTALL_SCRIPT"
fi

hash -r
swift --version
echo "ci-install-swift-linux: installed Swift ${SWIFT_VERSION}"
