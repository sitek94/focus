#!/usr/bin/env bash
# Static gate: notarization requires hardened runtime on Focus.app and every
# nested executable we ship (today: embedded focus CLI).
# Linux-safe — only inspects project.yml.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

python3 - <<'PY'
from pathlib import Path
import sys

lines = Path("project.yml").read_text().splitlines()
required = ["FocusMac", "FocusCLI"]
current = None
blocks: dict[str, list[str]] = {name: [] for name in required}

for line in lines:
    stripped = line.strip()
    # Target headers are indented two spaces: `  FocusMac:`
    if line.startswith("  ") and not line.startswith("    ") and stripped.endswith(":"):
        name = stripped[:-1]
        current = name if name in blocks else None
        continue
    if current is not None:
        blocks[current].append(line)

missing = [
    name
    for name, body in blocks.items()
    if not any("ENABLE_HARDENED_RUNTIME" in ln and "YES" in ln for ln in body)
]
if missing:
    print(
        "error: ENABLE_HARDENED_RUNTIME: YES required for notarization on: "
        + ", ".join(missing),
        file=sys.stderr,
    )
    sys.exit(1)
print("assert-hardened-runtime: FocusMac + FocusCLI ok")
PY
