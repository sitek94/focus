# Changelog

All notable changes to Focus are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project uses [Semantic Versioning](https://semver.org/).

## [0.1.0] — Unreleased

### Added

- Foundation repository contracts: MIT license, third-party notices, agent docs,
  changelog, Makefile, and docs frontmatter tooling.
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
  `focus-testing`, `release-focus`) with provenance checks.
