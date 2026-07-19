---
summary: "Continuous iOS deploy: GitHub Actions archive upload to TestFlight internal."
read_when:
  - "Wiring iOS release/distribution"
  - "Debugging a failed Deploy iOS run"
  - "Changing TestFlight or App Store Connect configuration"
---

# Releasing (iOS)

Continuous deployment on push to `main` (path-scoped). Internal TestFlight
only — no Beta App Review. Marketing version stays in `Config/Shared.xcconfig`
(`0.1.0` until a manual milestone bump). Build number is the GitHub Actions
run number.

## Loop

1. Commit + push to `main` (paths under FocusIOS / shared Sources / Config / …).
2. `.github/workflows/deploy-ios.yml` runs:
   - selects pinned Xcode (`.xcode-version`), regenerates `Focus.xcodeproj`
   - archives `FocusIOS` with App Store Connect API auth + automatic signing
     (`-allowProvisioningUpdates`)
   - exports with `destination: upload` and
     `testFlightInternalTestingOnly: true` → App Store Connect / TestFlight
3. Install / update from the TestFlight app on the device (enable automatic
   updates for Focus).

Manual force: Actions → **Deploy iOS** → **Run workflow**.

## Prerequisites

One-time App Store Connect setup (owner):

1. Register / create app with bundle id `com.macieksitkowski.focus.ios`.
2. Add yourself to an internal TestFlight group; enable automatic distribution.
3. On iPhone: install TestFlight, install Focus, enable automatic updates.

Repository configuration (reuse the macOS notary API key):

- Secrets: `APPLE_NOTARY_API_PRIVATE_KEY`
- Variables: `APPLE_TEAM_ID`, `APPLE_NOTARY_API_KEY_ID`,
  `APPLE_NOTARY_API_ISSUER_ID`

Supporting script: `Scripts/release-ios-archive-upload.sh`. Export options:
`Config/ExportOptionsIOS.plist`.

## Notes

- No Sparkle-style self-update on iOS; Apple prohibits self-updating binaries.
- Internal TestFlight builds expire after 90 days; continuous deploys keep a
  fresh build available.
- Cloud signing on the hosted runner is the least-proven step; if it fails,
  fall back to an explicit Apple Distribution cert + profile (same pattern as
  the macOS Developer ID import).
