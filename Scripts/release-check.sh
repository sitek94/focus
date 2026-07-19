#!/usr/bin/env bash
# Validate tag/version consistency without publishing.
# Usage: Scripts/release-check.sh 0.1.0
# Optional: FOCUS_REQUIRE_RELEASE_SECRETS=1 to require signing/notary/Sparkle secrets.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

VERSION="${1:-${VERSION:-}}"
if [[ -z "$VERSION" ]]; then
  echo "usage: Scripts/release-check.sh <X.Y.Z>" >&2
  exit 1
fi

if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z.+-]+)?$ ]]; then
  echo "error: VERSION must look like SemVer (got '${VERSION}')" >&2
  exit 1
fi

TAG="v${VERSION}"
echo "release-check: validating ${TAG} / ${VERSION}"

required_files=(
  LICENSE
  project.yml
  Package.swift
  Config/Shared.xcconfig
  docs/release-macos.md
  docs/release-ios.md
  docs/sparkle.md
)
for path in "${required_files[@]}"; do
  if [[ ! -f "$path" ]]; then
    echo "error: missing required file: ${path}" >&2
    exit 1
  fi
done

# Single source of truth for marketing/build versions.
marketing_xcconfig="$(
  awk -F' *= *' '/^MARKETING_VERSION/ { print $2; exit }' Config/Shared.xcconfig
)"
build_xcconfig="$(
  awk -F' *= *' '/^CURRENT_PROJECT_VERSION/ { print $2; exit }' Config/Shared.xcconfig
)"

if grep -Eq '^[[:space:]]*MARKETING_VERSION:' project.yml \
  || grep -Eq '^[[:space:]]*CURRENT_PROJECT_VERSION:' project.yml; then
  echo "error: version keys must live only in Config/Shared.xcconfig (not project.yml)" >&2
  exit 1
fi
if [[ "$marketing_xcconfig" != "$VERSION" ]]; then
  echo "error: Config/Shared.xcconfig MARKETING_VERSION='${marketing_xcconfig}' != '${VERSION}'" >&2
  exit 1
fi
if [[ -z "$build_xcconfig" ]]; then
  echo "error: CURRENT_PROJECT_VERSION missing from Config/Shared.xcconfig" >&2
  exit 1
fi
if ! [[ "$build_xcconfig" =~ ^[0-9]+$ ]]; then
  echo "error: CURRENT_PROJECT_VERSION must be an integer build number (got '${build_xcconfig}')" >&2
  exit 1
fi

echo "release-check: MARKETING_VERSION=${VERSION}, CURRENT_PROJECT_VERSION=${build_xcconfig}"

# Optional local tag presence check (CI release workflow checks out the tag).
if git rev-parse -q --verify "refs/tags/${TAG}" >/dev/null 2>&1; then
  echo "release-check: local tag ${TAG} exists"
else
  echo "release-check: local tag ${TAG} not present (ok for pre-tag dry runs)"
fi

placeholder_edkey="AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
if grep -Fq "INFOPLIST_KEY_SUPublicEDKey: ${placeholder_edkey}" project.yml; then
  echo "error: SUPublicEDKey is still the all-zero placeholder" >&2
  exit 1
fi
if ! grep -Eq 'INFOPLIST_KEY_SUPublicEDKey:[[:space:]]*[A-Za-z0-9+/=]{40,}' project.yml; then
  echo "error: SUPublicEDKey missing or malformed in project.yml" >&2
  exit 1
fi
echo "release-check: SUPublicEDKey present in project.yml"

if grep -Eq 'INFOPLIST_KEY_SUFeedURL:[[:space:]]*https://' project.yml; then
  echo "release-check: Sparkle feed URL present in project.yml"
fi

check_secret_name() {
  local name="$1"
  if [[ -n "${!name:-}" ]]; then
    echo "release-check: secret/var ${name} is set"
    return 0
  fi
  echo "release-check: secret/var ${name} is unset (optional until real release)"
  return 1
}

missing_secrets=0
for name in \
  APPLE_DEVELOPER_ID_APPLICATION_P12_BASE64 \
  APPLE_DEVELOPER_ID_APPLICATION_P12_PASSWORD \
  APPLE_NOTARY_API_PRIVATE_KEY \
  SPARKLE_ED25519_PRIVATE_KEY \
  APPLE_TEAM_ID \
  APPLE_NOTARY_API_KEY_ID \
  APPLE_NOTARY_API_ISSUER_ID
do
  if ! check_secret_name "$name"; then
    missing_secrets=$((missing_secrets + 1))
  fi
done

if [[ "${FOCUS_REQUIRE_RELEASE_SECRETS:-0}" == "1" && "$missing_secrets" -gt 0 ]]; then
  echo "error: FOCUS_REQUIRE_RELEASE_SECRETS=1 but ${missing_secrets} release secret(s)/var(s) missing" >&2
  exit 1
fi

echo "release-check: ok (structural; signing/notary/Sparkle secrets optional unless FOCUS_REQUIRE_RELEASE_SECRETS=1)"
