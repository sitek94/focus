---
name: release-focus
description: >
  Focus release router: continuous macOS/iOS deploy, notarization, Sparkle
  appcast, and secret-safety. Use when changing deploy workflows or release docs.
---

# Release Focus

## Read first

1. `docs/release-macos.md` — continuous Developer ID + notarize + Sparkle deploy.
2. `docs/release-ios.md` — continuous internal TestFlight deploy.
3. `docs/sparkle.md` — EdDSA key split, appcast hosting, update smoke expectations.

## Exact checks

```bash
make release-check VERSION=x.y.z   # no publish
make docs-list
```

Primary path: path-filtered push to `main` runs `deploy-macos.yml` /
`deploy-ios.yml`. Optional manual signed-tag path: `release.yml`
(`workflow_dispatch`).

## Secret safety

- Never print, echo, or commit key material (Developer ID `.p12`, notary API key, Sparkle Ed25519 private key).
- Private Sparkle key stays in `SPARKLE_ED25519_PRIVATE_KEY`; only the public key belongs in app config (`SUPublicEDKey`).
- Ordinary CI (`.github/workflows/ci.yml`) is `contents: read` only: unsigned archive gate, no release secrets, no appcast mutation on merge.
- Deploy workflows fail closed when required secrets are missing. Do not put
  owner-specific vault paths or credential locators in this skill.

## Out of scope

- Homebrew taps/casks.
- Owner machine paths, personal credential locators, or private release vaults.
- Interactive notarization debugging beyond `docs/release-macos.md` and the
  release scripts.
