---
summary: "Continuous macOS deploy: Developer ID, notarize, Sparkle from push to main."
read_when:
  - "Changing archive, notarization, or deploy workflow steps"
  - "Wiring macOS signing secrets or Sparkle keys"
  - "Debugging a failed Deploy macOS run"
---

# Releasing (macOS)

Continuous deployment on push to `main` (path-scoped). No signed tags, no
changelog ceremony. Marketing version stays in `Config/Shared.xcconfig`
(`0.1.0` until a manual milestone bump). Build number is the GitHub Actions
run number.

## Loop

1. Commit + push to `main` (paths under FocusMac / shared Sources / Config / …).
2. `.github/workflows/deploy-macos.yml` runs:
   - selects pinned Xcode (`.xcode-version`), regenerates `Focus.xcodeproj`
   - imports Developer ID, archives, notarizes, generates Sparkle `appcast.xml`
   - publishes a GitHub Release `macos-build-<run_number>` with `--generate-notes`
     (DMG + `appcast.xml`) and marks it `--latest`
3. Installed apps pick up the update via Sparkle (see `docs/sparkle.md`).
4. Never ship iOS artifacts from this workflow (guarded). See `docs/release-ios.md`.

Manual force: Actions → **Deploy macOS** → **Run workflow**.

## CI vs deploy

| Surface | Workflow | Signing / secrets |
|---|---|---|
| Push / PR health | `.github/workflows/ci.yml` | `contents: read`; unsigned archive gate; no release secrets |
| Continuous deploy | `.github/workflows/deploy-macos.yml` | Requires signing + notary + Sparkle secrets; fails closed if missing |
| Legacy tag cut | `.github/workflows/release.yml` | Optional secrets; skipped when absent — delete in Phase 4 |

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
`Scripts/archive-macos-ci.sh`. Sparkle keys and feed hosting: `docs/sparkle.md`.
