---
summary: "Sparkle key handling, silent auto-update, idle relaunch, and feed hosting."
read_when:
  - "Wiring Sparkle into FocusMac"
  - "Generating or hosting appcast.xml"
  - "Debugging automatic update checks"
---

# Sparkle updates

Audience: contributors wiring or debugging FocusMac auto-update.

Sparkle is a remote package on the `FocusMac` target only (pin and Info.plist
keys live in `project.yml`). It is not part of the portable SwiftPM graph.

## Wiring

- `UpdatePreferencesClient` owns `SPUStandardUpdaterController` on `@MainActor`
  and implements `SPUUpdaterDelegate`.
- Settings menu exposes an automatic-check toggle, “Check for Updates…”, and a
  build label (`Focus <marketing> (<build>) · <short commit>`).
- Sparkle keys live in `Apps/Focus/FocusMac/Resources/Info.plist` (also
  declared under `info.properties` in `project.yml`). Do not use
  `INFOPLIST_KEY_SU*` — Xcode’s generated Info.plist path silently drops
  unknown keys.
  - `SUPublicEDKey` — live Ed25519 public key (private key never in source)
  - `SUFeedURL` — public GitHub Releases `…/latest/download/appcast.xml`
  - `SUEnableAutomaticChecks` / `SUAutomaticallyUpdate` — automatic silent updates
  - `SUScheduledCheckInterval` — `3600` (one hour)
  - `FocusGitCommit` — `$(FOCUS_GIT_COMMIT)` (`local` locally; SHA in deploy)
- `make assert-sparkle-info-plist` (in `verify-linux`) and the macOS archive
  script both fail closed if `SUFeedURL` is missing.

## Idle relaunch

Focus is a menu-bar app that rarely quits. When Sparkle schedules a silent
install-on-quit, `UpdatePreferencesClient` takes control via
`willInstallUpdateOnQuit` and calls the immediate install handler only when no
warning or break UI is active. Pending installs retry after those UI states
clear and on app activation. A background check also runs on launch and
activation when no Sparkle session is in progress.

## Keys and feed

- Ed25519 private key stays in release secret `SPARKLE_ED25519_PRIVATE_KEY`.
- `appcast.xml` is a release artifact (gitignored), not hand-edited source.
- Feed URL must stay publicly readable.
- `generate_appcast` runs in `deploy-macos.yml` after
  `Scripts/ci-install-sparkle-tools.sh` installs the pinned Sparkle tools.

## Smoke

End-to-end update from an older signed build is credentialed Mac acceptance, not
a Linux check. Never put a GitHub token in the app.

See [release-macos.md](./release-macos.md) for the publish loop.
