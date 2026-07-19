# Continuous personal deployment — implementation plan

> Working plan, 2026-07-19. Carries the locked decision until it is promoted to
> `docs/release-*.md` + ADR 0002 in Phase 4, then delete this file.
>
> Execution stance: the agent does everything it can (gh CLI, App Store Connect
> API, local keygen); the owner only acts where Apple requires a human in their
> web UI or on the device. Owner-facing steps are marked **OWNER**.

## Locked decision (recap)

- macOS: Developer ID + notarize + Sparkle, silent auto-install. Direct
  distribution, never Mac App Store (sandbox breaks the blocker).
- iOS: internal TestFlight (no Beta App Review), auto-updates on device.
- GitHub Actions for everything; no Xcode Cloud.
- Repo goes public → Sparkle feed URL works as-is, macOS runner minutes free.
- **Trunk-based, no PRs:** work on `main` locally, commit + push. That push
  is the deploy trigger.
- Auto-deploy on push to `main`, path-scoped per platform, push bursts
  collapse via `cancel-in-progress`, `workflow_dispatch` as force/escape hatch.
- Build number = workflow run number; `MARKETING_VERSION` stays `0.1.0` until a
  manual milestone bump; commit hash embedded in the app.
- No changesets, no changelog file, no signed-tag ceremony. GH release notes
  from commit messages (`--generate-notes`).
- Deploys do NOT wait on `ci.yml`: `ci.yml` runs on push as a health signal;
  deploys build what they ship and fail visibly. Fix forward.

## Owner involvement — the complete list

1. Approve the repo→public command (Phase 0).
2. Create one App Store Connect API key in the ASC web UI (no API exists for
   this — it is the bootstrap credential), download the `.p8`, give the agent
   its path + Key ID + Issuer ID (Phase 1).
3. Click through "New App" in App Store Connect for the iOS bundle ID — the
   official ASC API cannot create app records (Phase 3).
4. On the iPhone: install TestFlight, accept the invite, install Focus, enable
   automatic updates (Phase 3).
5. Incidentals: possible one-click Keychain "Allow" during local key export;
   possible CSR upload at developer.apple.com if the API cert path is blocked.

Everything else — repo flip, secret/variable uploads, Sparkle keygen, cert
provisioning, bundle-ID registration, TestFlight group + tester setup, local
install smoke — is agent-executed.

## Phase 0 — take the repo public

- [x] Agent: secret-scan full git history (gitleaks) and report findings.
      Result 2026-07-19: `gitleaks detect --log-opts=--all` — 43 commits,
      no leaks.
- [x] Agent: sanity pass — LICENSE present, no personal data in tracked files.
      No credential filenames; no private-key markers in history.
- [x] Repo already `PUBLIC` (`gh repo view` → `visibility: PUBLIC`). No flip
      needed.

Result: Sparkle feed URL fetchable; Actions minutes free (macOS runners
included).

## Phase 1 — macOS continuous deployment

Credentials (one-time):

- [ ] **OWNER**: create ASC API key named `Focus CI` (blocked while Apple
      Developer Program renewal processes). Role: Admin. Hand agent `.p8`
      path + Key ID + Issuer ID.
- [ ] Agent: `gh secret set APPLE_NOTARY_API_PRIVATE_KEY < key.p8`;
      `gh variable set` for `APPLE_NOTARY_API_KEY_ID`,
      `APPLE_NOTARY_API_ISSUER_ID`. Never print key material.
- [x] Agent: `APPLE_TEAM_ID=8N24XF84J5` set as repo variable.
- [ ] **OWNER**: export Developer ID Application `.p12` via Keychain Access
      (CLI export failed without interactive keychain unlock); give agent
      path + password → agent uploads secrets and shreds local copies.
- [x] Agent: Sparkle keys generated (`--account focus`), private key in
      `SPARKLE_ED25519_PRIVATE_KEY`, public key in `project.yml`.

Commit 1 on `main` (`deploy-macos.yml` + prerequisites):

- [ ] `ENABLE_HARDENED_RUNTIME = YES` in `Config/Shared.xcconfig`
      (notarization hard-requires it; currently missing).
- [ ] De-duplicate versioning: `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION`
      live in BOTH `project.yml` and `Config/Shared.xcconfig` — keep
      `Shared.xcconfig` as the single source, drop from `project.yml`.
- [ ] New `Scripts/ci-install-sparkle-tools.sh`: download Sparkle release
      tools, pinned (version + sha256) in the script with a comment tying it
      to the `project.yml` Sparkle revision. Closes the "generate_appcast not
      on PATH" gap in `release-generate-appcast.sh`.
- [ ] New `.github/workflows/deploy-macos.yml`:
      - `on: push` to `main` with mac paths (below) + `workflow_dispatch`
      - `concurrency: deploy-macos`, `cancel-in-progress: true`
      - `macos-26`, select-xcode, `make generate-project`
      - reuse `release-import-signing.sh` → archive/export with
        `CURRENT_PROJECT_VERSION=${{ github.run_number }}` and
        `FOCUS_GIT_COMMIT=${{ github.sha }}` → `release-notarize.sh` →
        install sparkle tools → `release-generate-appcast.sh`
      - `gh release create macos-build-${{ github.run_number }}`
        `--latest --generate-notes` + DMG + `appcast.xml`
      - keep the existing "never ship iOS artifacts from the Mac leg" guard
- [ ] Adapt `release-archive-export.sh`: version arg becomes
      marketing+build-number aware; DMG name includes build number.
- [ ] Rewrite `docs/release-macos.md` in the same commit: continuous
      deployment is the release path (frontmatter stays `docs-list` valid).

Acceptance (agent-driven):

- [ ] Push a trivial change to `main` → GH release appears with notarized DMG
      + signed appcast. Agent installs the DMG locally (hdiutil attach →
      copy to /Applications) and launches it.
- [ ] Push a second change → installed app sees and applies the update.

## Phase 2 — Mac update behavior (app-side)

Commit 2 on `main`:

- [x] `project.yml`: real `SUPublicEDKey`, `SUAutomaticallyUpdate: YES`,
      `SUScheduledCheckInterval: 3600`.
- [x] Background check on launch/activation when none is running.
- [x] Relaunch policy: Focus is a menu-bar app that never quits, so a
      downloaded update would sit pending forever. Add an `SPUUpdaterDelegate`
      seam: when an update is pending and the session is idle (not in
      warning/break), install + relaunch.
- [x] Embed commit: `INFOPLIST_KEY_FocusGitCommit = $(FOCUS_GIT_COMMIT)`;
      surface build number + commit in the settings menu ("is my fix live?").
- [x] Update `docs/sparkle.md`: real key posture, silent-update settings,
      relaunch policy.

Acceptance:

- [ ] Update lands hands-free within ~1h of push (or immediately on app
      activation), never during a break. (Verify after this commit deploys.)

## Phase 3 — iOS continuous deployment (TestFlight)

Setup:

- [ ] Agent: register bundle id `com.macieksitkowski.focus.ios` via ASC API
      (`POST /v1/bundleIds`).
- [ ] **OWNER**: create the app record in the ASC UI (~3 min; not in the
      official API).
- [ ] Agent: create the internal TestFlight beta group + add owner as tester
      via ASC API (`POST /v1/betaGroups`, `/v1/betaTesters`).
- [ ] **OWNER**: on the iPhone — install TestFlight, install Focus, enable
      automatic updates.

Commit 3 on `main` (`deploy-ios.yml` + signing settings):

- [ ] `project.yml` (FocusIOS): `DEVELOPMENT_TEAM`, `CODE_SIGN_STYLE:
      Automatic`, `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption: NO`
      (kills the per-build export-compliance prompt that would otherwise block
      every TestFlight build).
- [ ] New `Config/ExportOptionsIOS.plist`: `method: app-store-connect`,
      `destination: upload`, `testFlightInternalTestingOnly: true`.
- [ ] New `.github/workflows/deploy-ios.yml`:
      - `on: push` to `main` with iOS paths (below) + `workflow_dispatch`
      - `concurrency: deploy-ios`, `cancel-in-progress: true`
      - archive FocusIOS with cloud signing: `-allowProvisioningUpdates`
        + ASC API key (`-authenticationKeyPath/-authenticationKeyID/`
        `-authenticationKeyIssuerID`), `CURRENT_PROJECT_VERSION=run_number`,
        `FOCUS_GIT_COMMIT=sha`
      - `-exportArchive` with the upload ExportOptions → straight to
        App Store Connect / TestFlight. No fastlane.
- [ ] Rewrite `docs/release-ios.md` in the same commit (drops the Xcode Cloud
      plan; GH Actions is the implemented path).

Spike risk (the least-proven piece): xcodebuild cloud signing on a hosted
runner with the generated project. Fallback if it fights back: mint an Apple
Distribution cert + App Store profile via the ASC API and import them the same
way `release-import-signing.sh` does for Developer ID.

Acceptance:

- [ ] Push an iOS-touching change to `main` → build in TestFlight in
      ~10–15 min (upload + Apple processing) → phone updates automatically
      (or manual tap in TestFlight for fastest).

## Phase 4 — delete ceremony, promote docs

Commit 4 on `main`:

- [ ] Delete `.github/workflows/release.yml`, `Scripts/release-check.sh`,
      `Scripts/verify-signed-tag.sh`; drop the `release-check` Makefile
      target.
- [ ] New `docs/adr/0002-continuous-personal-deployment.md`: the decision
      record — strategy split (Sparkle vs TestFlight), GH-Actions-everywhere,
      public repo, trunk-based no-PR, run-number versioning, no-ceremony —
      with the rejected alternatives (Xcode Cloud, TestFlight-for-Mac,
      changesets, PR-gated deploy) and why.
- [ ] Update `AGENTS.md` (command table: drop `release-check`) and
      `.agents/skills/release-focus/SKILL.md` (currently anchored on
      release-check + signed tags).
- [ ] Delete `publish-plan.md`.

## Path scoping

| Trigger paths | deploy-macos | deploy-ios |
|---|---|---|
| `Apps/Focus/FocusMac/**`, `CLI/**` | ✅ | — |
| `Apps/Focus/FocusIOS/**` | — | ✅ |
| `Sources/**`, `Package.swift`, `project.yml`, `Config/**`, `tools/projectgen/**`, `.xcode-version` | ✅ | ✅ |
| own workflow file + scripts it runs | ✅ | ✅ |
| `docs/**`, `*.md`, `Tests/**`, `Apps/Focus/*Tests/**`, `.agents/**` | — | — |

Shared rows are duplicated across the two workflow files — keep in sync (comment
in each file points at the other).

## Deliberate simplifications

- Build numbers are per-workflow run numbers → Mac and iOS sequences diverge;
  the embedded commit hash is the cross-platform identity. Re-running an old
  run reuses its number (TestFlight rejects duplicates) — retry = fresh
  dispatch or new commit.
- One GH release per Mac deploy (`macos-build-N` tags). History is free
  artifact retention; no rollback machinery.
- No deploy → CI dependency; `ci.yml` stays as a push-to-`main` health
  signal (its `pull_request` trigger can stay; unused if we never open PRs).
- iOS leg creates no GH release; TestFlight holds the artifacts.
- Day-to-day loop: notice issue → agent commits on `main` → push → deploy.
