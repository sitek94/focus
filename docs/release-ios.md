---
summary: "Continuous iOS deploy: GitHub Actions archive upload to TestFlight internal."
read_when:
  - "Wiring iOS release/distribution"
  - "Debugging a failed Deploy iOS run"
  - "Changing TestFlight or App Store Connect configuration"
---

# Releasing (iOS)

Audience: contributors changing iOS deploy or TestFlight wiring.

Continuous deployment on path-filtered push to `main`, plus manual
`workflow_dispatch`. Internal TestFlight only—no Beta App Review. Marketing
version stays in `Config/Shared.xcconfig` (and the deploy workflow
`MARKETING_VERSION` env) until you bump it for a milestone. Build number is the
GitHub Actions run number.

## Loop

1. Push to `main` on paths under FocusIOS, shared Sources, Config, project
   generation, or the deploy scripts/workflow (see
   `.github/workflows/deploy-ios.yml`).
2. Deploy iOS runs on `macos-26`:
   - selects pinned Xcode (`.xcode-version`), regenerates `Focus.xcodeproj`
   - archives `FocusIOS` with App Store Connect API auth and automatic signing
     (`-allowProvisioningUpdates`)
   - exports with `destination: upload` and
     `testFlightInternalTestingOnly: true` → App Store Connect / TestFlight
3. Install or update from the TestFlight app on the device (enable automatic
   updates for Focus).

Force a run: Actions → Deploy iOS → Run workflow.

## Prerequisites

One-time App Store Connect setup:

1. Register the app with bundle id `com.macieksitkowski.focus.ios`.
2. Add yourself to an internal TestFlight group; enable automatic distribution.
3. On iPhone: install TestFlight, install Focus, enable automatic updates.

Repository configuration (reuse the macOS notary API key):

- Secrets: `APPLE_NOTARY_API_PRIVATE_KEY`
- Variables: `APPLE_TEAM_ID`, `APPLE_NOTARY_API_KEY_ID`,
  `APPLE_NOTARY_API_ISSUER_ID`

Supporting script: `Scripts/release-ios-archive-upload.sh`. Export options:
`Config/ExportOptionsIOS.plist`.

## Notes

- iOS has no Sparkle-style self-update; Apple prohibits self-updating binaries.
- Internal TestFlight builds expire after 90 days; continuous deploys keep a
  fresh build available.
- macOS continuous deploy is separate: [release-macos.md](./release-macos.md).
