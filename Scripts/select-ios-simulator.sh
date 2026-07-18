#!/usr/bin/env bash
# Dynamically pick an available iOS 26 Simulator destination for smoke-ios.
# Prints the xcodebuild -destination value; also exports IOS_DESTINATION and
# writes it to GITHUB_ENV when present.
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "error: select-ios-simulator.sh requires macOS" >&2
  exit 1
fi

# Prefer a booted iPhone on iOS 26.x, else any available iPhone on iOS 26.x.
destination="$(
  python3 - <<'PY'
import json
import subprocess
import sys

raw = subprocess.check_output(
    ["xcrun", "simctl", "list", "--json", "devices", "available"],
    text=True,
)
data = json.loads(raw)
devices = data.get("devices", {})

candidates = []
for runtime, runtime_devices in devices.items():
    # runtime keys look like "com.apple.CoreSimulator.SimRuntime.iOS-26-0"
    if "iOS-26" not in runtime and "iOS 26" not in runtime:
        continue
    for device in runtime_devices:
        if device.get("isAvailable") is False:
            continue
        name = device.get("name", "")
        if "iPhone" not in name:
            continue
        udid = device.get("udid")
        if not udid:
            continue
        state = device.get("state", "")
        # Prefer booted devices, then iPhone 16 / 17 family naming loosely by order.
        priority = 0
        if state == "Booted":
            priority += 100
        if "Pro" in name:
            priority += 1
        candidates.append((priority, name, udid, runtime))

if not candidates:
    print("error: no available iOS 26 iPhone simulator found", file=sys.stderr)
    # Helpful dump for CI logs
    for runtime in sorted(devices):
        if "iOS" in runtime:
            print(f"  runtime: {runtime}", file=sys.stderr)
            for device in devices[runtime][:5]:
                print(
                    f"    {device.get('name')} "
                    f"available={device.get('isAvailable')} "
                    f"state={device.get('state')}",
                    file=sys.stderr,
                )
    sys.exit(1)

candidates.sort(reverse=True)
_, name, udid, runtime = candidates[0]
print(f"platform=iOS Simulator,id={udid}", end="")
print(f"\n# selected {name} ({runtime})", file=sys.stderr)
PY
)"

# Strip any accidental trailing commentary; destination is the python stdout line.
destination="${destination%%$'\n'*}"

if [[ -z "$destination" || "$destination" != platform=iOS\ Simulator,id=* ]]; then
  echo "error: failed to resolve iOS 26 simulator destination" >&2
  exit 1
fi

export IOS_DESTINATION="$destination"
if [[ -n "${GITHUB_ENV:-}" ]]; then
  echo "IOS_DESTINATION=${destination}" >>"$GITHUB_ENV"
fi

printf '%s\n' "$destination"
echo "select-ios-simulator: ${destination}" >&2
