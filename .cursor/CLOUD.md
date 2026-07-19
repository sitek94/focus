# Cursor Cloud

Cursor Cloud agents run on Linux (Ubuntu 24.04, x86_64). This environment has
Swift 6.3.3 via [`swiftly`](https://www.swift.org/install/) under
`~/.local/share/swiftly` (on `PATH` for login and non-login shells). Confirm
with `swift --version`. Do not upgrade the toolchain without also updating
package manifests, CI pins, `.swift-version`, and this file.

## Linux vs Apple

There is no Xcode, Simulator, or Apple SDK here. Code that imports `UIKit`,
`SwiftUI`, or `AppKit`, or that needs `xcodebuild`, cannot run on Linux. Keep
Apple imports in Apple-only targets. Do not add pre-26 availability guards.

Linux is authoritative for:

- portable `FocusSession`, `FocusPersistence`, `FocusControl`, and `focus`
- Linux SQLite, CLI, and Unix-socket integration tests
- docs, license, dependency, formatting, and static boundary checks
- XcodeGen syntax/determinism (not Xcode 26.6 build compatibility)

Use GitHub-hosted `macos-26` CI
(`/Applications/Xcode_26.6.app/Contents/Developer`) for generation, Apple SDK
builds, Darwin IPC/`getpeereid`, Simulator, XCUITest, and smoke tests. An
interactive Mac is still required for VoiceOver, multi-display/Spaces behavior,
Dockless no-flash, login-item revoke, App Translocation CLI install, and
signed/notarized Sparkle updates.

Apple Developer membership, signing credentials, Sparkle keys, feed hosting,
and TestFlight can wait until release work. Apple portions of a PR need working
`macos-26` Actions access.

## SwiftPM package shape

```swift
// swift-tools-version: 6.3
platforms: [.iOS(.v26), .macOS(.v26)],
swiftLanguageModes: [.v6]
```

Optional per-target settings: `.enableUpcomingFeature("...")` (e.g.
`ExistentialAny`, `InternalImportsByDefault`).

## External reference clones

When a session must inspect an external repo beyond what docs already record:

1. Inventory repositories and exact commit SHAs.
2. Clone under `/workspace/tmp/references/`, one directory per repo + full SHA.
3. Check out that SHA detached; verify remote, `HEAD`, and a clean worktree.
   Recurse submodules only when the source uses them.
4. Reuse a clone only when remote, SHA, and clean state match; otherwise make a
   fresh uniquely named clone. Never inspect a mutable default branch in place.
5. Treat clones as read-only. Research subagents do not commit or push.

`tmp/` must never be committed. Use explicit-path `git add` (never `git add .`);
reject any staged `tmp/` path. The parent agent owns commits and pushes.

## Commands

Prefer root `Makefile` / `AGENTS.md` targets (`make verify-linux`,
`make test-linux`, …). From a package directory:

- `swift build` / `swift test` / `swift run [TargetName]`
- `swift format lint --recursive Sources Tests`
- `swift format --in-place --recursive Sources Tests`

## Notes

- Bundled `swift format` defaults to 2-space indent.
- Delete `.build/` if you hit stale-build issues.
