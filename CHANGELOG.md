# Changelog

All notable changes to Focus are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project uses [Semantic Versioning](https://semver.org/).

## [0.1.0] — Unreleased

### Added

- Foundation repository contracts: MIT license, third-party notices, agent docs,
  changelog, Makefile, and docs frontmatter tooling.
- Root SwiftPM package with portable libraries `FocusSession`,
  `FocusPersistence`, `FocusControl`, and executable `focus`.
- XcodeGen 2.46.0 project graph (`project.yml`, `tools/projectgen`) generating
  ignored `Focus.xcodeproj` for `FocusMac`, `FocusIOS`, embedded `FocusCLI`,
  and placeholder Apple test targets.
- Minimal macOS MenuBarExtra shell (`LSUIElement`) and iOS app shell.
- Concurrency-safety and skill-provenance check scripts.
