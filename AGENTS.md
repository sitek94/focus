# Focus agent guide

## Before architecture, testing, or release work

Run `make docs-list` and read every doc whose `read_when` matches the task.
Keep commands here and in the `Makefile`; put detailed rationale in the owning
`docs/` page.

## Canonical commands

| Command | Meaning |
|---|---|
| `make docs-list` | Validate and list docs frontmatter |
| `make format` | `swift format --in-place` on `Sources Tests CLI Apps` |
| `make lint` | Format lint + concurrency-safety scan |
| `make generate-project` | Pinned XcodeGen → root `Focus.xcodeproj` (ignored) |
| `make assert-swift-toolchain` / `assert-generated-project` | Pin checks for Swift 6.3.3 and `objectVersion = 90` / untracked project |
| `make test-linux` | `swift test` (portable subset) |
| `make test-session` / `test-persistence` / `test-control` / `test-cli` / `test-platform-gating` | Focused SwiftPM filters |
| `make build-macos` / `make build-ios` | Generate + `xcodebuild` (macOS only) |
| `make test-macos-integration` / `smoke-macos` / `smoke-ios` / `archive-macos` | Apple CI targets (macOS only; `ARCHIVE_MODE=ci` for unsigned gate) |
| `make verify-linux` | Toolchain assert, docs, lint, build, portable tests |
| `make verify-apple` | Xcode select, generate, both builds, integration, smokes, archive |
| `make release-check VERSION=x.y.z` | Tag/changelog/version/key presence checks (no publish) |

Underlying pins:

```sh
swift run --package-path tools/projectgen xcodegen generate --spec project.yml --project .
swift build
swift test
```

Toolchain pins live in one-line root files: `.swift-version` (swiftly) and
`.xcode-version` (the Xcode marketing version). `select-xcode` reads
`.xcode-version` and honors an already-correct `DEVELOPER_DIR` or active
`xcode-select` first (no sudo); otherwise it falls back to
`/Applications/Xcode_<version>.app` and `sudo xcode-select -s`. Local dev with a
plain `Xcode.app`: `export DEVELOPER_DIR="$(xcode-select -p)"` (once it points at
the pinned version) and every `make` Apple target works without sudo.

Apple targets are `ARCHS = arm64` only (macOS/iOS 26 are Apple-silicon only); do
not reintroduce an x86_64 slice.

## Proof boundary

| Authoritative on Linux | Requires macOS + Xcode 26.6 |
|---|---|
| Portable `FocusSession`, `FocusPersistence`, `FocusControl`, `focus` CLI | `FocusMac` / `FocusIOS` builds, archives, UI tests |
| Linux SQLite + Unix-socket CLI integration tests | Darwin IPC (`getpeereid`), login item, overlays |
| Docs, license, format | Sparkle install/update, notarization, VoiceOver |
| Deterministic XcodeGen generation (syntax only) | Generated project compatibility with Xcode 26 |

Linux generation does **not** prove Xcode can build the project. Do not import
`SwiftUI`, `AppKit`, or `UIKit` from `Sources/` or `CLI/`.

Cursor Cloud agents: see `.cursor/CLOUD.md` for the Linux toolchain and Apple
SDK boundary.

## Feature-first rules

- One owner per state domain; thin views; isolated services/actors.
- Fixed timing only (20m focus / 10s warning / 20s break / 60s snooze) — never
  preferences, CLI flags, or settings knobs for durations.
- No stats, history UI, blocking, gamification, telemetry, accounts, Homebrew,
  or website in this slice.
- Prefer Swift Testing on portable suites; XCUITest only for minimal Apple smoke.

## Generated-project rules

- Edit `project.yml` and `Config/*.xcconfig`, never hand-edit generated
  `Focus.xcodeproj`.
- `Focus.xcodeproj` is gitignored and must stay untracked.
- Pin XcodeGen 2.46.0 at `8445e778451c7e44237b90281bde622d764b0084` via
  `tools/projectgen`.
- `options.projectFormat: xcode16_3` is required.
- If Mac CI proves XcodeGen cannot represent the Xcode 26 project, switch once
  to a checked-in native project and update ADR 0001 — do not maintain both.

## Concurrency

Swift 6 mode is mandatory. Reject `@unchecked Sendable`, `nonisolated(unsafe)`,
`MainActor.assumeIsolated`, and `@preconcurrency` in shipped/test Swift
(`make lint` / `Scripts/check-concurrency-safety.swift`).

## Docs map

| Path | Owns |
|---|---|
| `docs/architecture/overview.md` | Targets, IDs, ownership |
| `docs/architecture/session.md` | State machine and time |
| `docs/architecture/cli.md` | CLI/IPC contract |
| `docs/testing.md` | Test lanes |
| `docs/release-macos.md` | macOS release checklist |
| `docs/release-ios.md` | iOS release path (TODO, not yet implemented) |
| `docs/sparkle.md` | Updates / appcast |
| `docs/adr/0001-project-generation.md` | XcodeGen decision |
| `docs/adr/0002-cli-ipc.md` | Socket IPC decision |

## Git hygiene

- Never commit `tmp/`, `/tmp/` research clones, or `Focus.xcodeproj`.
- Use explicit-path `git add`; inspect `git diff --cached --name-only` before
  every commit.
