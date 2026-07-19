---
summary: "Continuous macOS deploy: Developer ID, notarize, Sparkle from push to main."
read_when:
  - "Changing archive, notarization, or deploy workflow steps"
  - "Wiring macOS signing secrets or Sparkle keys"
  - "Debugging a failed Deploy macOS run"
---

# Releasing (macOS)

Audience: contributors changing macOS deploy, signing, or Sparkle publish.

Continuous deployment on path-filtered push to `main`, plus manual
`workflow_dispatch`. Marketing version stays in `Config/Shared.xcconfig` (and
the deploy workflow `MARKETING_VERSION` env) until you bump it for a milestone.
Build number is the GitHub Actions run number. Commit hash is embedded as
`FOCUS_GIT_COMMIT`.

## Loop

1. Push to `main` on paths under FocusMac, shared Sources, Config, project
   generation, or the deploy scripts/workflow (see
   `.github/workflows/deploy-macos.yml`).
2. Deploy macOS runs on `macos-26`:
   - selects pinned Xcode (`.xcode-version`), regenerates `Focus.xcodeproj`
   - imports Developer ID, archives, notarizes, generates Sparkle `appcast.xml`
   - publishes a GitHub Release `macos-build-<run_number>` with
     `--generate-notes` (DMG + `appcast.xml`) and marks it `--latest`
3. Installed apps pick up the update via Sparkle (see [sparkle.md](./sparkle.md)).

Force a run: Actions → Deploy macOS → Run workflow.

This workflow must not ship iOS artifacts (guarded in the job). iOS deploy:
[release-ios.md](./release-ios.md).

## CI vs deploy

| Surface | Workflow | Signing / secrets |
|---|---|---|
| Push / PR health | `.github/workflows/ci.yml` | `contents: read`; unsigned archive gate; no release secrets |
| Continuous deploy | `.github/workflows/deploy-macos.yml` | Requires signing, notary, and Sparkle secrets; fails closed if missing |
| Manual tag release | `.github/workflows/release.yml` | `workflow_dispatch` with an existing `vX.Y.Z` tag; optional secrets skip steps when absent |

Deploys do not wait on `ci.yml`. CI is a health signal; deploy builds what it
ships.

## Prerequisites

Repository configuration (never put secret values in source):

- Secrets: `APPLE_DEVELOPER_ID_APPLICATION_P12_BASE64`,
  `APPLE_DEVELOPER_ID_APPLICATION_P12_PASSWORD`, `APPLE_NOTARY_API_PRIVATE_KEY`,
  `SPARKLE_ED25519_PRIVATE_KEY`
- Variables: `APPLE_TEAM_ID`, `APPLE_NOTARY_API_KEY_ID`,
  `APPLE_NOTARY_API_ISSUER_ID`

Do not create both a secret and a variable for the same identifier. The workflow
uses its scoped built-in `GITHUB_TOKEN`; no personal access token is required.

Supporting scripts: `Scripts/release-*.sh`, `Scripts/ci-install-sparkle-tools.sh`,
`Scripts/archive-macos-ci.sh`. Sparkle keys and feed hosting:
[sparkle.md](./sparkle.md). Dry-run checks without publishing:
`make release-check VERSION=x.y.z`.
