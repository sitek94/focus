---
summary: "Planned iOS release path (Xcode Cloud, TestFlight internal-only); not implemented yet."
read_when:
  - "Wiring iOS release/distribution"
  - "Lifting the iOS-artifact release guard"
  - "Deciding TestFlight or App Store Connect configuration"
---

# Releasing (iOS)

No iOS release pipeline exists yet. `FocusIOS` is built and smoke-tested only;
`.github/workflows/release.yml` forbids publishing iOS/`ipa` artifacts (see
`docs/release-macos.md`).

## Planned approach

- **Xcode Cloud** for the iOS build/upload leg (not GitHub Actions/Fastlane).
  Apple manages signing and uploads to App Store Connect.
- **TestFlight internal testing only** — no App Review for internal testers on
  the owner's Apple Developer account.
- No Sparkle-style self-update on iOS; Apple prohibits self-updating binaries.
- Internal TestFlight builds expire after 90 days; re-upload as needed.

## Open when implementing

- Lift or scope the `release.yml` iOS-artifact guard.
- Decide whether Xcode Cloud triggers off the same signed tag as macOS release,
  or independently off `main`/a branch.
