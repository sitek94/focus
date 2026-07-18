#!/usr/bin/env bash
# After XcodeGen, assert objectVersion = 90 and that Focus.xcodeproj stays untracked.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

PBXPROJ="Focus.xcodeproj/project.pbxproj"

if [[ ! -f "$PBXPROJ" ]]; then
  echo "error: missing ${PBXPROJ}; run make generate-project first" >&2
  exit 1
fi

object_version="$(
  awk -F'=|;' '/objectVersion/ { gsub(/[[:space:]]/, "", $2); print $2; exit }' "$PBXPROJ"
)"
if [[ "$object_version" != "90" ]]; then
  echo "error: expected objectVersion = 90, found '${object_version:-<missing>}'" >&2
  exit 1
fi
echo "assert-generated-project: objectVersion = 90"

tracked="$(git ls-files -- "Focus.xcodeproj" || true)"
if [[ -n "$tracked" ]]; then
  echo "error: Focus.xcodeproj must remain untracked; git ls-files reported:" >&2
  printf '%s\n' "$tracked" >&2
  exit 1
fi
echo "assert-generated-project: Focus.xcodeproj is untracked"

if git check-ignore -q Focus.xcodeproj || git check-ignore -q Focus.xcodeproj/; then
  echo "assert-generated-project: Focus.xcodeproj is gitignored"
else
  echo "error: Focus.xcodeproj is not ignored by .gitignore" >&2
  exit 1
fi

echo "assert-generated-project: ok"
