#!/usr/bin/env bash
# Placeholder signed-tag verification against a checked-in allowed-signers policy.
# Policy file (when present): Config/git-allowed-signers
# No tag-signing private key belongs in repository secrets.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

TAG="${1:-}"
if [[ -z "$TAG" ]]; then
  echo "usage: Scripts/verify-signed-tag.sh <vX.Y.Z>" >&2
  exit 1
fi

if [[ ! "$TAG" =~ ^v[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z.+-]+)?$ ]]; then
  echo "error: tag must look like vX.Y.Z (got '${TAG}')" >&2
  exit 1
fi

if ! git rev-parse -q --verify "refs/tags/${TAG}" >/dev/null 2>&1; then
  echo "error: tag ${TAG} not found in this clone" >&2
  exit 1
fi

echo "verify-signed-tag: found ${TAG} -> $(git rev-list -n 1 "refs/tags/${TAG}")"

POLICY="Config/git-allowed-signers"
if [[ ! -f "$POLICY" ]]; then
  if [[ "${FOCUS_REQUIRE_SIGNED_TAG:-0}" == "1" ]]; then
    echo "error: ${POLICY} is required when FOCUS_REQUIRE_SIGNED_TAG=1 (refusing unsigned-tag release)" >&2
    exit 1
  fi
  cat <<EOF
verify-signed-tag: PLACEHOLDER
  No ${POLICY} policy file is checked in yet.
  When Maciek adds SSH/GPG allowed signers, this script will verify the tag
  signature against that policy (git verify-tag / ssh key allowedSignersFile).
  Continuing without cryptographic verification for foundation CI wiring.
  Set FOCUS_REQUIRE_SIGNED_TAG=1 to fail closed (release workflow).
EOF
  exit 0
fi

# Future: honor git config gpg.format / ssh.allowedSignersFile from Config/.
export GIT_SSH_COMMAND="${GIT_SSH_COMMAND:-ssh}"
if git config --local --get gpg.ssh.allowedSignersFile >/dev/null 2>&1; then
  :
else
  git config --local gpg.ssh.allowedSignersFile "$ROOT/$POLICY" || true
fi

if git verify-tag "$TAG" 2>&1; then
  echo "verify-signed-tag: ${TAG} signature ok"
  exit 0
fi

echo "error: tag ${TAG} failed signature verification against ${POLICY}" >&2
exit 1
