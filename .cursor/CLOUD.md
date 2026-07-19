# Cursor Cloud instructions

## Cursor Cloud specific instructions

### Environment overview
This repo is for building iOS / macOS projects with Swift. Cursor Cloud agents run on
**Linux (Ubuntu 24.04, x86_64)**, so the environment is set up for the **cross-platform
Swift** parts of such projects: the Swift compiler and Swift Package Manager (SwiftPM).

The project-pinned Swift toolchain (**Swift 6.3.3**) is installed via
[`swiftly`](https://www.swift.org/install/) under `~/.local/share/swiftly`. It is on
`PATH` for both login shells (via `~/.profile`) and non-login shells (via `~/.bashrc`),
so `swift` just works in new terminals. Confirm with `swift --version`. Do not upgrade it
without also updating package manifests, CI pins, `.swift-version`, and the toolchain
documentation; upstream release pages can briefly disagree about the newest patch.

### Project target: iOS/macOS 26+, latest language features (private project)
This is a private project targeting the latest OS versions with the newest Swift features.
Configure new SwiftPM packages accordingly (verified to parse/build on this toolchain):

```swift
// swift-tools-version: 6.3
platforms: [.iOS(.v26), .macOS(.v26)],
// ...
swiftLanguageModes: [.v6]   // Swift 6 language mode = strict concurrency + newest features
```

- `.iOS(.v26)` / `.macOS(.v26)` and `swiftLanguageModes: [.v6]` are supported by Swift 6.3.3.
- Opt into newer semantics per-target via `swiftSettings: [.enableUpcomingFeature("...")]`
  (e.g. `ExistentialAny`, `InternalImportsByDefault`).
- Latest language features such as typed throws (`func f() throws(MyError)`) and actors
  compile and test fine on Linux.
- The actual **iOS 26 / macOS 26 SDK builds and simulator/device runs require Xcode 26 on
  a Mac** — only the cross-platform Swift can be exercised here (see limitation below).
### Important limitation (read this first)
There is **no Xcode, no iOS/macOS Simulator, and no Apple SDKs** on Linux. You **cannot**
build/run code that imports `UIKit`, `SwiftUI`, `AppKit`, or uses `xcodebuild`/`.xcodeproj`
schemes here. Only code that compiles against the open-source Swift stdlib + `Foundation`
(SwiftPM libraries/executables, shared model/business logic) can be built, tested, and
run in this environment. Keep Apple imports in Apple-only targets. Use conditional
compilation only at genuine shared platform seams; do not add compatibility availability
guards for pre-26 operating systems.

### Focus execution boundary
A Cursor Cloud agent may author any tracked file, including Apple-target source, but Linux
runtime proof is authoritative only for:

- the portable `FocusSession`, `FocusPersistence`, `FocusControl`, and `focus` SwiftPM work;
- Linux SQLite, CLI, and Unix-socket integration tests;
- docs, license, dependency, formatting, and static boundary checks;
- deterministic XcodeGen generation and confirmation that generated projects stay untracked.

A successful Linux XcodeGen run proves generator syntax and determinism only. It does not
prove that Xcode 26.6 can build or archive the generated project.

Use GitHub-hosted `macos-26` CI with
`/Applications/Xcode_26.6.app/Contents/Developer` for Xcode generation/build/archive,
Apple SDK compilation, Darwin-only IPC and `getpeereid`, Simulator, XCUITest, and the
minimal macOS/iOS smoke tests.

An interactive physical or remote Mac remains required for VoiceOver/Accessibility
Inspector, real multi-display and fullscreen/Spaces/Stage Manager behavior, Dockless
no-flash behavior, logout/login and login-item revocation, App Translocation and CLI
install/repair, and signed/notarized Sparkle install/update testing.

Local Mac setup is not a prerequisite for starting portable work. Apple Developer
membership, bundle registration, Developer ID/notary credentials, Sparkle private keys,
public feed hosting, and TestFlight setup can wait until release-focused work. Apple
portions of a PR require working `macos-26` Actions access before they can be accepted.

### Session bootstrap for external sources
When a session needs to inspect an external repository beyond what docs already
record:

1. Inventory the repositories and exact commit SHAs needed for that work.
2. Materialize them under `/workspace/tmp/references/`, one unique directory per
   repository and pinned full commit SHA.
3. Check out the exact SHA in detached state and verify the canonical remote,
   `HEAD`, and a clean worktree. Recurse submodules only when the source uses them.
4. Reuse a clone only when remote, SHA, and clean state all match; otherwise create
   a fresh uniquely named clone. Never silently inspect a mutable default branch.
5. Treat reference clones as read-only. Research subagents must not commit or push
   from them.

`tmp/` is transient and must never be committed. Use explicit-path `git add`
commands, never `git add .`; before every commit, inspect
`git diff --cached --name-only` and reject any `tmp/` path. The parent agent owns
git commits and pushes; research subagents only report findings.

### Common commands (run from a package dir containing `Package.swift`)
- Build: `swift build`
- Run an executable target: `swift run [TargetName]`
- Test: `swift test` (works with both XCTest and the Swift Testing framework)
- Lint: `swift format lint --recursive Sources Tests`
- Auto-format: `swift format --in-place --recursive Sources Tests`

Canonical Focus commands live in the root `Makefile` and `AGENTS.md` (`make verify-linux`,
`make test-linux`, and related targets).

### Notes / gotchas
- `swift format` is bundled with the toolchain (no separate install). Its default style is
  **2-space indentation**, which differs from the 4-space style in `swift package init`
  templates — expect indentation warnings on freshly scaffolded code until formatted.
- To start a new package: `swift package init --type executable` (or `--type library`).
- The build cache lives in `.build/`; delete it (`rm -rf .build`) if you hit stale-build issues.
