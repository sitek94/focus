---
summary: "Monorepo directories, portable vs Apple boundary, and target identifiers."
read_when:
  - "Adding or renaming a library, app, CLI, or test target"
  - "Deciding whether code belongs in Sources/, CLI/, or Apps/"
  - "Changing bundle identifiers or product names"
---

# Repository layout

Focus is a monorepo with a portable SwiftPM core and an XcodeGen-generated
Apple project. This page covers directories, identifiers, and the Linux vs
Apple proof boundary.

## Directories

| Path | Role |
|---|---|
| `Sources/` | Portable libraries (`FocusSession`, `FocusPersistence`, `FocusControl`, `CSQLite`) |
| `CLI/FocusCLI/` | `focus` executable sources |
| `Apps/Focus/` | macOS and iOS UI shells (Apple frameworks only here) |
| `Tests/` | SwiftPM test suites |
| `Config/` | Shared xcconfig, export options, identifiers |
| `project.yml` + `tools/projectgen/` | XcodeGen pin; generated `Focus.xcodeproj` is gitignored |
| `Scripts/` | CI, release, and assert helpers |
| `docs/` | Contributing documentation (this tree) |

Portable code under `Sources/` and `CLI/` must not import `SwiftUI`, `AppKit`,
or `UIKit`.

## SwiftPM products

| Product | Depends on |
|---|---|
| `FocusSession` | — |
| `FocusPersistence` | `FocusSession`, system `CSQLite` |
| `FocusControl` | `FocusSession` |
| `focus` | `FocusControl` |

## Xcode targets

| Target | Bundle identifier |
|---|---|
| `FocusMac` | `com.macieksitkowski.focus.macos` |
| `FocusIOS` | `com.macieksitkowski.focus.ios` |
| `FocusCLI` | `com.macieksitkowski.focus.cli` |
| `FocusMacIntegrationTests` | `com.macieksitkowski.focus.macos.tests` |
| `FocusMacUITests` | `com.macieksitkowski.focus.macos.uitests` |
| `FocusIOSUITests` | `com.macieksitkowski.focus.ios.uitests` |

`com.macieksitkowski.focus` is the namespace prefix, not a concrete target.

## Proof boundary

Linux is authoritative for portable libraries, CLI tests, docs, and XcodeGen
syntax. macOS with pinned Xcode is required for app builds, archives, Darwin
IPC, UI tests, Sparkle, and notarization. Linux generation does not prove Xcode
can build the project.

Full table and command index: [`AGENTS.md`](../AGENTS.md). Cursor Cloud notes:
[`.cursor/CLOUD.md`](../.cursor/CLOUD.md).

## Project generation

Edit `project.yml` and `Config/*.xcconfig`. Do not hand-edit generated
`Focus.xcodeproj`. Decision record:
[ADR 0001](./adr/0001-project-generation.md).

## Non-scope

Session policy, CLI command semantics, and UI feature ownership are out of
scope on this page.
