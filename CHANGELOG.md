# Changelog

All notable changes to Focus are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project uses [Semantic Versioning](https://semver.org/).

## [0.1.0] — Unreleased

### Fixed

- `FocusMacApp` attached `.task` to a `Scene`, which does not compile; moved the
  bootstrap onto the menu-bar label view so the macOS app builds.
- `FocusPlatformGatingTests` asserted the Linux peer checker unconditionally;
  gated the assertion so the portable suite also passes on macOS hosts.

### Changed

- Apple targets build `arm64` only (`ARCHS = arm64`); macOS/iOS 26 are
  Apple-silicon only, so the former universal build's x86_64 slice was dead
  weight and broke against arm64-only Homebrew SQLite.
- Xcode pin moved to a root `.xcode-version` file (sibling of `.swift-version`).
  `select-xcode` reads it and prefers an already-correct `DEVELOPER_DIR` or
  active `xcode-select` before the `sudo` fallback, so local Apple builds no
  longer require sudo.
- Removed setup-only `PLAN.md` and `THIRD_PARTY_NOTICES.md`; durable contracts
  live in `docs/`, `LICENSE`, and agent skills without source-provenance tables.

### Added

- Foundation repository contracts: MIT license, agent docs, changelog, Makefile,
  and docs frontmatter tooling.
- Deterministic `FocusSession` reducer with fixed 20m/10s/20s/1m policy and
  Linux manual-clock tests.
- SQLite `FocusPersistence` actor store (`schema_meta`, `runtime_snapshot`,
  `outcome_events`) with atomic commit/rollback integration tests.
- `FocusControl` length-prefixed JSON Unix-socket protocol and `focus` CLI with
  human/`--json` output plus Linux socket integration tests.
- XcodeGen 2.46.0 project graph generating ignored `Focus.xcodeproj` for
  `FocusMac`, `FocusIOS`, embedded `FocusCLI`, and Apple test targets.
- macOS MenuBarExtra vertical slice (`LSUIElement`): runtime owner, warning
  panel, multi-display break overlay seams, launch-at-login adapter, CLI
  install/repair, and Sparkle 2.9.4 wiring with placeholder public key.
- Minimal iOS shell importing shared core, plus platform UI smoke skeletons.
- GitHub Actions Linux + `macos-26`/Xcode 26.6 CI and secret-gated release
  workflow definitions.
- Focus-adapted agent skills (`focus-swiftui`, `focus-concurrency`,
  `focus-testing`, `release-focus`).
