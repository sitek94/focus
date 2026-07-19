#!/usr/bin/env bash
# Static gate: Sparkle keys must live in FocusMac's Info.plist source.
# INFOPLIST_KEY_SU* is not enough — Xcode drops unknown generated keys.
# Linux-safe (plistlib).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

python3 - <<'PY'
from pathlib import Path
import plistlib
import sys

plist_path = Path("Apps/Focus/FocusMac/Resources/Info.plist")
if not plist_path.is_file():
    print(
        f"error: missing {plist_path} (Sparkle keys cannot use INFOPLIST_KEY_* alone)",
        file=sys.stderr,
    )
    sys.exit(1)

with plist_path.open("rb") as fh:
    info = plistlib.load(fh)

required = [
    "SUFeedURL",
    "SUPublicEDKey",
    "SUEnableAutomaticChecks",
    "SUAutomaticallyUpdate",
    "SUScheduledCheckInterval",
    "FocusGitCommit",
]
missing = [key for key in required if key not in info]
if missing:
    print(f"error: {plist_path} missing required keys: {', '.join(missing)}", file=sys.stderr)
    sys.exit(1)

feed = info["SUFeedURL"]
if not (isinstance(feed, str) and feed.startswith("https://") and feed.endswith("appcast.xml")):
    print(f"error: SUFeedURL looks wrong: {feed}", file=sys.stderr)
    sys.exit(1)

project = Path("project.yml").read_text()
if "INFOPLIST_KEY_SUFeedURL" in project or "INFOPLIST_KEY_SUPublicEDKey" in project:
    print(
        "error: Sparkle keys must not use INFOPLIST_KEY_* in project.yml (Xcode drops them)",
        file=sys.stderr,
    )
    sys.exit(1)

print(f"assert-sparkle-info-plist: ok ({feed})")
PY
