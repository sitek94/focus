---
summary: "Sparkle key handling, appcast generation, feed hosting, and update smoke expectations."
read_when:
  - "Wiring Sparkle into FocusMac"
  - "Generating or hosting appcast.xml"
  - "Debugging automatic update checks"
---

# Sparkle updates

Sparkle is a remote package on the `FocusMac` target only (pin and Info.plist
keys live in `project.yml`). It is not part of the portable SwiftPM graph.

## Wiring

- `UpdatePreferencesClient` owns `SPUStandardUpdaterController` on `@MainActor`.
- Settings menu exposes automatic-check toggle + “Check for Updates…”.
- Replace the placeholder `SUPublicEDKey` in `project.yml` before shipping
  signed updates. Private key never belongs in source.

## Keys and feed

- Ed25519 private key stays in release secret `SPARKLE_ED25519_PRIVATE_KEY`;
  only the public key belongs in app configuration (`SUPublicEDKey`).
- `appcast.xml` is a release artifact (gitignored), not hand-edited source.
- Feed URL must stay publicly readable (currently GitHub Releases
  `…/latest/download/appcast.xml`; see `SUFeedURL` in `project.yml`).
- `generate_appcast` runs in `release.yml` only when the private key secret is
  present; otherwise the step skips with a clear log.

## Smoke

End-to-end update from an older signed build is credentialed Mac acceptance, not
a Linux check. Never put a GitHub token in the app.
