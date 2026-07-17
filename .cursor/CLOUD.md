# Cursor Cloud instructions

## Cursor Cloud specific instructions

### Environment overview
This repo is for building iOS / macOS projects with Swift. Cursor Cloud agents run on
**Linux (Ubuntu 24.04, x86_64)**, so the environment is set up for the **cross-platform
Swift** parts of such projects: the Swift compiler and Swift Package Manager (SwiftPM).

The Swift toolchain (**Swift 6.3.3**, the latest stable swift.org release) is installed via
[`swiftly`](https://www.swift.org/install/) under `~/.local/share/swiftly`. It is on
`PATH` for both login shells (via `~/.profile`) and non-login shells (via `~/.bashrc`),
so `swift` just works in new terminals. Upgrade later with `swiftly install latest && swiftly use latest`.

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
- Being private has no effect on the Linux dev flow; no license/OSS scaffolding is needed.

### Important limitation (read this first)
There is **no Xcode, no iOS/macOS Simulator, and no Apple SDKs** on Linux. You **cannot**
build/run code that imports `UIKit`, `SwiftUI`, `AppKit`, or uses `xcodebuild`/`.xcodeproj`
schemes here. Only code that compiles against the open-source Swift stdlib + `Foundation`
(SwiftPM libraries/executables, server-side Swift, shared model/business logic) can be
built, tested, and run in this environment. For Apple-framework code, guard it with
`#if canImport(UIKit)` / `#if os(iOS)` etc., and do the Xcode/simulator build & UI testing
on a Mac.

### Common commands (run from a package dir containing `Package.swift`)
- Build: `swift build`
- Run an executable target: `swift run [TargetName]`
- Test: `swift test` (works with both XCTest and the Swift Testing framework)
- Lint: `swift format lint --recursive Sources Tests`
- Auto-format: `swift format --in-place --recursive Sources Tests`

### Notes / gotchas
- `swift format` is bundled with the toolchain (no separate install). Its default style is
  **2-space indentation**, which differs from the 4-space style in `swift package init`
  templates — expect indentation warnings on freshly scaffolded code until formatted.
- To start a new package: `swift package init --type executable` (or `--type library`).
- The build cache lives in `.build/`; delete it (`rm -rf .build`) if you hit stale-build issues.
- The repo root currently has no `Package.swift`. Create your SwiftPM package (in the root
  or a subdirectory) and run the commands above from that package's directory.
