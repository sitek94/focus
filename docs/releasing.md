---
summary: "Versioning, tagging, archive/sign/notarize checklist, and release prerequisites for Focus."
read_when:
  - "Preparing a version bump or Git tag"
  - "Changing archive, notarization, or release workflow steps"
  - "Running make release-check"
---

# Releasing

Versioning starts at `0.1.0`. Tags are `vX.Y.Z`, signed locally by the owner,
pushed before the release workflow runs. No tag-signing private key belongs in
repository secrets.

## Checklist (high level)

1. Changelog section and `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` agree
   with the tag (`Config/Shared.xcconfig` and `project.yml`).
2. `make release-check VERSION=x.y.z` passes (no publish).
3. Push the signed tag, then run `.github/workflows/release.yml`
   (`workflow_dispatch` with required `tag` input). The workflow:
   - checks out the tag and runs the signed-tag policy placeholder
     (`Scripts/verify-signed-tag.sh`; real verification when
     `Config/git-allowed-signers` exists)
   - selects Xcode 26.6, regenerates `Focus.xcodeproj`
   - imports Developer ID / archives / notarizes / generates Sparkle appcast
     only when the corresponding secrets/vars are present; otherwise those
     steps skip with an explicit log line
   - creates a **draft** GitHub Release (DMG first, then `appcast.xml`) when a
     signed DMG was produced
4. Clean-Mac install/update smoke, then publish the draft.
5. Never release the iOS shell (workflow guard forbids iOS/`ipa` artifacts).

## CI vs release

| Surface | Workflow | Signing / secrets |
|---|---|---|
| PR / `main` | `.github/workflows/ci.yml` | `contents: read` only; unsigned archive gate; no release secrets |
| Cut a version | `.github/workflows/release.yml` | Secrets optional until real release; skipped when absent |

Ordinary CI never signs, notarizes, creates tags, publishes releases, or
modifies `appcast.xml` on merge.

## Prerequisites

Owner-supplied (see `PLAN.md` §15 for the full matrix):

- Secrets: `APPLE_DEVELOPER_ID_APPLICATION_P12_BASE64`,
  `APPLE_DEVELOPER_ID_APPLICATION_P12_PASSWORD`, `APPLE_NOTARY_API_PRIVATE_KEY`,
  `SPARKLE_ED25519_PRIVATE_KEY`
- Variables: `APPLE_TEAM_ID`, `APPLE_NOTARY_API_KEY_ID`,
  `APPLE_NOTARY_API_ISSUER_ID`

Supporting scripts live under `Scripts/release-*.sh`,
`Scripts/verify-signed-tag.sh`, and `Scripts/archive-macos-ci.sh`. Details for
Sparkle keys and feed hosting live in `docs/sparkle.md`.
