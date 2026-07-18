---
name: release-focus
description: >
  Focus release router: versioning, signed tags, notarization gates, Sparkle
  appcast, and secret-safety. Use when cutting a version or editing release
  workflows/docs.
---

# Release Focus

## Provenance

| Field       | Value                                                                                                                |
| ----------- | -------------------------------------------------------------------------------------------------------------------- |
| Upstream    | Focus-authored                                                                                                       |
| License     | N/A (original Focus text)                                                                                            |
| Disposition | **original**                                                                                                         |
| Inspiration | CodexBar release workflow _shape_ and official Apple/Sparkle docs — **not** copied text, paths, or vault assumptions |

## Read first

1. `docs/releasing.md` — versioning, tag policy, `make release-check`, CI vs release workflows.
2. `docs/sparkle.md` — Sparkle 2.9.4 pin, Ed25519 key split, appcast hosting, update smoke expectations.
3. `THIRD_PARTY_NOTICES.md` — Sparkle notice obligations when shipping.

## Exact checks

```bash
make release-check VERSION=x.y.z   # no publish
make docs-list
```

Before cutting a tag:

1. `CHANGELOG.md` section matches `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` and tag `vX.Y.Z`.
2. `make release-check VERSION=x.y.z` passes.
3. Owner signs the tag locally; no tag-signing private key in repository secrets.
4. Push the signed tag, then run `.github/workflows/release.yml` with the `tag` input.
5. Confirm draft GitHub Release (DMG then `appcast.xml`) only when signing secrets produced a signed DMG.
6. Clean-Mac install/update smoke, then publish the draft.
7. Never ship the iOS shell (`ipa` / iOS artifacts forbidden).

## Secret safety

- Never print, echo, or commit key material (Developer ID `.p12`, notary API key, Sparkle Ed25519 private key).
- Private Sparkle key stays in `SPARKLE_ED25519_PRIVATE_KEY`; only the public key belongs in app config (`SUPublicEDKey`).
- Ordinary CI (`.github/workflows/ci.yml`) is `contents: read` only: unsigned archive gate, no release secrets, no appcast mutation on merge.
- Release workflow steps that need secrets must **skip with an explicit log** when absent—do not invent owner-specific vault paths or 1Password item IDs in this skill.

## Out of scope for this skill

- Homebrew taps/casks (Focus v1 does not ship Homebrew).
- Owner machine paths, personal credential locators, or private release vaults.
- Interactive notarization debugging beyond what `docs/releasing.md` and the release scripts already describe.
