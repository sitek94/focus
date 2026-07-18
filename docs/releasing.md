---
summary: "Versioning, tagging, archive/sign/notarize checklist, and release prerequisites for Focus."
read_when:
  - "Preparing a version bump or Git tag"
  - "Changing archive, notarization, or release workflow steps"
  - "Running make release-check"
---

# Releasing

Versioning starts at `0.1.0`. Tags are `vX.Y.Z`, signed locally by the owner,
pushed before the release workflow runs.

## Checklist (high level)

1. Changelog section and `MARKETING_VERSION` / build number agree with the tag.
2. `make release-check VERSION=x.y.z` passes (no publish).
3. `release.yml` (`workflow_dispatch`) checks out the tag, verifies the signed
   tag, regenerates the project, archives arm64 `Focus.app` with Hardened
   Runtime, notarizes the DMG, generates the Sparkle appcast, and drafts the
   GitHub Release.
4. Never release the iOS shell.

## Prerequisites

Secrets and Apple program membership are owner-supplied and optional until an
actual release. CI must not sign or publish on ordinary merges. See `PLAN.md`
§15 for the full prerequisite matrix and secret/variable names.

Details for Sparkle keys and feed hosting live in `docs/sparkle.md`.
