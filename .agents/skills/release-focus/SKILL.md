---
name: release-focus
description: >
  Focus release router: versioning, signed tags, notarization gates, Sparkle
  appcast, and secret-safety. Use when cutting a version or editing release
  workflows/docs.
---

# Release Focus

## Read first

1. `docs/release-macos.md` — versioning, tag policy, checklist, `make release-check`, CI vs release workflows.
2. `docs/release-ios.md` — iOS release path (TODO, not yet implemented); why the iOS shell never ships from `release.yml`.
3. `docs/sparkle.md` — Sparkle 2.9.4 pin, EdDSA key split, appcast hosting, update smoke expectations.

## Exact checks

```bash
make release-check VERSION=x.y.z   # no publish
make docs-list
```

`docs/release-macos.md` owns the current tag/release checklist; read it before
cutting a tag rather than following a copy here.

## Secret safety

- Never print, echo, or commit key material (Developer ID `.p12`, notary API key, Sparkle Ed25519 private key).
- Private Sparkle key stays in `SPARKLE_ED25519_PRIVATE_KEY`; only the public key belongs in app config (`SUPublicEDKey`).
- Ordinary CI (`.github/workflows/ci.yml`) is `contents: read` only: unsigned archive gate, no release secrets, no appcast mutation on merge.
- Release workflow steps that need secrets must **skip with an explicit log** when absent—do not invent owner-specific vault paths or 1Password item IDs in this skill.

## Out of scope for this skill

- Homebrew taps/casks (Focus v1 does not ship Homebrew).
- Owner machine paths, personal credential locators, or private release vaults.
- Interactive notarization debugging beyond what `docs/release-macos.md` and the release scripts already describe.
