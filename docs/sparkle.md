---
summary: "Sparkle 2.9.4 key handling, appcast generation, feed hosting, and update smoke expectations."
read_when:
  - "Wiring Sparkle into FocusMac"
  - "Generating or hosting appcast.xml"
  - "Debugging automatic update checks"
---

# Sparkle updates

Focus uses Sparkle **2.9.4** at commit
`b6496a74a087257ef5e6da1c5b29a447a60f5bd7` for direct Developer ID distribution.

## Wiring (FocusMac only)

Sparkle is linked through XcodeGen/`project.yml` as a remote Swift package on the
`FocusMac` target only — not the portable SwiftPM package.

- `UpdatePreferencesClient` owns `SPUStandardUpdaterController` on `@MainActor`.
- Settings menu exposes automatic-check toggle + “Check for Updates…”.
- Info.plist keys (via `project.yml`):
  - `SUFeedURL` —
    `https://github.com/sitek94/focus/releases/latest/download/appcast.xml`
  - `SUPublicEDKey` — placeholder all-zero Ed25519 public key
    (`AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=`). Replace with the real
    public key before shipping signed updates.
  - `SUEnableAutomaticChecks` — `YES` by default; user preference is Sparkle-owned.

## Keys and feed

- Ed25519 private key stays in release secret `SPARKLE_ED25519_PRIVATE_KEY`;
  only the public key belongs in app configuration (`SUPublicEDKey`).
- `appcast.xml` is a release artifact (gitignored), not hand-edited source.
- Feed URL (requires publicly readable release assets):
  `https://github.com/sitek94/focus/releases/latest/download/appcast.xml`
- Minimum system `26.0`, hardware `arm64`.
- `generate_appcast` runs in `release.yml` only when the private key secret is
  present; otherwise the step skips with a clear log.

## Smoke

End-to-end update from an older signed build is credentialed Mac acceptance, not
a Linux check. Never put a GitHub token in the app.
