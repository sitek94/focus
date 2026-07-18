---
summary: "TODO: planned iOS release path (Xcode Cloud, TestFlight internal-only) — not yet implemented."
read_when:
  - "Wiring iOS release/distribution"
  - "Lifting the iOS-artifact release guard"
  - "Deciding TestFlight or App Store Connect configuration"
---

# Releasing (iOS) — TODO, not yet implemented

No iOS release pipeline exists yet. `FocusIOS` is built and smoke-tested only;
`.github/workflows/release.yml` explicitly forbids publishing iOS/`ipa`
artifacts (see `docs/release-macos.md`). This doc records the planned
approach so the eventual implementation isn't designed from scratch.

## Planned approach

- **Xcode Cloud**, not GitHub Actions/Fastlane, for the iOS build/upload leg.
  Apple manages signing automatically and uploads straight to App Store
  Connect — no certificate/profile secrets to mint or rotate, unlike the
  Developer ID path macOS uses.
- **TestFlight internal testing only.** Focus is a personal-use app; internal
  testers on the owner's own Apple Developer account get builds with no App
  Review step (review is required only for external testers). This is the
  closest iOS equivalent to Sparkle's auto-update UX available on the
  platform.
- No Sparkle equivalent on iOS: Apple prohibits self-updating app binaries
  outright, App Store or not. There is no direct-distribution option to
  design around.
- Internal TestFlight builds expire after 90 days; expect to re-upload
  periodically even without new changes.

## Open when implementing

- Lift or scope the `release.yml` iOS-artifact guard once this path exists.
- Decide whether Xcode Cloud triggers off the same signed tag as
  `docs/release-macos.md`, or independently off `main`/a branch.
- Add the doc-map rows in `AGENTS.md` / `PLAN.md` §16 pointing here (already
  present) and drop this TODO framing once the pipeline is real.
