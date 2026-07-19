---
summary: "Target graph, bundle identifiers, ownership, and dependency direction for Focus."
read_when:
  - "Adding or renaming a library, app, CLI, or test target"
  - "Changing bundle identifiers or product names"
  - "Deciding whether code belongs in Sources/, CLI/, or Apps/"
---

# Architecture overview

Focus is a monorepo with a portable SwiftPM core and an XcodeGen-generated
Apple project.

## SwiftPM products

| Product | Role | Depends on |
|---|---|---|
| `FocusSession` | Deterministic session reducer, fixed policy, injected time | — |
| `FocusPersistence` | SQLite runtime snapshot and outcome log | `FocusSession`, system `CSQLite` |
| `FocusControl` | JSON protocol, framing, socket transport, DTOs | `FocusSession` |
| `focus` | Portable CLI parsing/rendering + platform-gated launch | `FocusControl` |

Portable code lives under `Sources/` and `CLI/FocusCLI/`. It must not import
`SwiftUI`, `AppKit`, or `UIKit`.

## Xcode targets

| Target | Identifier | Role |
|---|---|---|
| `FocusMac` | `com.macieksitkowski.focus.macos` | Menu-bar macOS app |
| `FocusIOS` | `com.macieksitkowski.focus.ios` | Minimal iOS shell |
| `FocusCLI` | `com.macieksitkowski.focus.cli` | Embedded `focus` binary |
| `FocusMacIntegrationTests` | `com.macieksitkowski.focus.macos.tests` | Darwin IPC / adapters |
| `FocusMacUITests` | `com.macieksitkowski.focus.macos.uitests` | Launch/menu smoke |
| `FocusIOSUITests` | `com.macieksitkowski.focus.ios.uitests` | Launch/root-scene smoke |

`com.macieksitkowski.focus` is the namespace prefix, not a concrete target.

## Ownership

- Session policy and transitions: `FocusSession` only.
- Persistence schema and transactions: `FocusPersistence` only.
- Wire protocol and socket rules: `FocusControl` only.
- UI and Apple SDK seams: `Apps/Focus/*` feature folders.
- Project structure: `project.yml` + `Config/`; generated `Focus.xcodeproj` is
  ignored.

### FocusMac owners

| Owner | Isolation | Domain |
|---|---|---|
| `FocusRuntimeOwner` | `@MainActor` | Current session, presentation directives, persistence commits |
| `WakeScheduler` | actor | Single next-deadline wake task |
| `ControlMailbox` + `ControlSocketServer` | actors | Socket accept/IO; mutations hop to MainActor |
| `OverlaySessionCoordinator` | `@MainActor` | Multi-display break windows |
| `WarningPanelCoordinator` | `@MainActor` | Compact warning panel |
| `LaunchAtLoginClient` | `@MainActor` | `SMAppService.mainApp` status |
| `UpdatePreferencesClient` | `@MainActor` | Sparkle updater preference/UI |
| `CLIInstaller` | `@MainActor` | Symlink install/repair diagnostics |
