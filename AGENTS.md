# Focus agent guide

## Before layout, testing, or release work

Run `make docs-list` and read every doc whose `read_when` matches the task.
Keep commands here and in the `Makefile`; put detailed rationale in the owning
`docs/` page. Doc map: [`docs/index.md`](./docs/index.md). Writing rules:
[`docs/writing-documentation.md`](./docs/writing-documentation.md).

## Canonical commands

| Command | Meaning |
|---|---|
| `make docs-list` | Validate and list docs frontmatter |
| `make format` | `swift format --in-place` on `Sources Tests CLI Apps` |
| `make lint` | Format lint + concurrency-safety scan |
| `make generate-project` | Pinned XcodeGen → root `Focus.xcodeproj` (ignored) |
| `make assert-swift-toolchain` / `assert-generated-project` | Pin checks (`.swift-version`, generated project format / untracked) |
| `make test-linux` | `swift test` (portable subset) |
| `make test-session` / `test-persistence` / `test-control` / `test-cli` / `test-platform-gating` | Focused SwiftPM filters |
| `make build-macos` / `make build-ios` | Generate + `xcodebuild` (macOS only) |
| `make test-macos-integration` / `smoke-macos` / `smoke-ios` / `archive-macos` | Apple CI targets (macOS only; `ARCHIVE_MODE=ci` for unsigned gate) |
| `make verify-linux` | Toolchain assert, docs, lint, build, portable tests |
| `make verify-apple` | Xcode select, generate, both builds, integration, smokes, archive |
| `make release-check VERSION=x.y.z` | Tag/version/key presence checks (no publish) |

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

| Authoritative on Linux | Requires macOS + pinned Xcode |
|---|---|
| Portable `FocusSession`, `FocusPersistence`, `FocusControl`, `focus` CLI | `FocusMac` / `FocusIOS` builds, archives, UI tests |
| Linux SQLite + Unix-socket CLI integration tests | Darwin IPC (`getpeereid`), login item, overlays |
| Docs, license, format | Sparkle install/update, notarization, VoiceOver |
| Deterministic XcodeGen generation (syntax only) | Generated project compatibility with pinned Xcode |

Linux generation does not prove Xcode can build the project. Do not import
`SwiftUI`, `AppKit`, or `UIKit` from `Sources/` or `CLI/`. Detail:
[`docs/layout.md`](./docs/layout.md).

Cursor Cloud agents: see `.cursor/CLOUD.md` for the Linux toolchain and Apple
SDK boundary.

## Contributing rules

- One owner per state domain; thin views; isolated services/actors.
- Prefer Swift Testing on portable suites; XCUITest only for minimal Apple smoke.
- Edit `project.yml` and `Config/*.xcconfig`, never hand-edit generated
  `Focus.xcodeproj`.
- `Focus.xcodeproj` is gitignored and must stay untracked.
- XcodeGen revision pin lives in `tools/projectgen`; do not fork a second pin.
- If Mac CI proves XcodeGen cannot represent the required project, switch once
  to a checked-in native project and update ADR 0001 — do not maintain both.

## Concurrency

Swift 6 mode is mandatory. Reject `@unchecked Sendable`, `nonisolated(unsafe)`,
`MainActor.assumeIsolated`, and `@preconcurrency` in shipped/test Swift
(`make lint` / `Scripts/check-concurrency-safety.swift`).
