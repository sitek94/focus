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

## Pins and notices

Recorded in `THIRD_PARTY_NOTICES.md`. Sparkle is Apple-only and is not linked
from the shared SwiftPM package. FocusMac Swift sources are not wired to Sparkle
in this CI/release-workflow checkpoint; appcast generation is release-pipeline
only for now (`Scripts/release-generate-appcast.sh`).

## Keys and feed

- Ed25519 private key stays in release secret `SPARKLE_ED25519_PRIVATE_KEY`;
  only the public key belongs in app configuration (`SUPublicEDKey`).
- `appcast.xml` is a release artifact (gitignored), not hand-edited source.
- Proposed feed:
  `https://github.com/sitek94/focus/releases/latest/download/appcast.xml`
  (requires publicly readable release assets).
- Minimum system `26.0`, hardware `arm64`.
- `generate_appcast` runs in `release.yml` only when the private key secret is
  present; otherwise the step skips with a clear log.

## Smoke

End-to-end update from an older signed build is credentialed Mac acceptance, not
a Linux check. Never put a GitHub token in the app.
