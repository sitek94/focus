---
name: focus-testing
description: >
  Focus testing router: Swift Testing suites, Linux-authoritative subset,
  XCUITest smokes, and no-screenshot rule. Use when adding, reviewing, or
  migrating Focus tests.
upstream: https://github.com/twostraws/Swift-Testing-Agent-Skill
commit: 2d6bba14a3c8bf3694f218b92fffe617c41ae43e
source_paths:
  - swift-testing-pro/skills/swift-testing-pro/SKILL.md
  - swift-testing-pro/references/core-rules.md
  - swift-testing-pro/references/writing-better-tests.md
  - swift-testing-pro/references/async-tests.md
license: MIT
disposition: adapted
---

# Focus Testing

## Provenance

| Field | Value |
|---|---|
| Upstream | https://github.com/twostraws/Swift-Testing-Agent-Skill |
| Commit | `2d6bba14a3c8bf3694f218b92fffe617c41ae43e` |
| License | MIT |
| Disposition | **adapted** (not copied) |
| Source paths | `swift-testing-pro/skills/swift-testing-pro/SKILL.md`; `references/core-rules.md`; `writing-better-tests.md`; `async-tests.md` |

Materially rewritten to route agents to Focus’s suites and CI boundaries (`PLAN.md` §12, `docs/testing.md`). Upstream feature-catalog dumps and XCTest migration essays are omitted unless a file still uses XCTest.

## Defaults

- New unit/integration tests: **Swift Testing** (`@Test`, `#expect` / `#require`, structs).
- UI tests: **XCTest** / XCUITest only (Swift Testing has no UI support).
- Swift 6.3 toolchain; treat installed toolchain as authoritative.
- Parallel-safe tests; inject clocks/clients; no real `Task.sleep` in portable suites.
- Prefer parameterized tests for phase/command matrices without exploding Cartesian products.

## Where tests live

| Suite | Lane | Covers |
|---|---|---|
| `FocusSessionTests` | Linux authoritative | Timing, transitions, pause/resume, catch-up, reconcile, fixed constants |
| `FocusPersistenceIntegrationTests` | Linux authoritative | Schema, atomic snapshot+events, restore, corrupt snapshot |
| `FocusControlTests` | Linux authoritative | Codable envelopes, framing, timeouts, path helpers |
| `FocusCLIIntegrationTests` | Linux authoritative | Real Unix socket fixture + CLI subprocess; all seven commands |
| `FocusPlatformGatingTests` | Linux authoritative | No Apple-framework leaks into portable targets |
| `FocusMacIntegrationTests` | Mac CI | Darwin socket, `getpeereid`, app handler, restart/timeout |
| `FocusMacUITests` | Mac CI | Minimal launch / menu-bar smoke |
| `FocusIOSUITests` | Mac CI | Minimal launch / root-scene smoke |

Commands: `make test-linux`, or focused `make test-session` / `test-persistence` / `test-control` / `test-cli` / `test-platform-gating`. Full policy: `docs/testing.md`.

## Hard rules

- **No screenshot-golden or visual-regression suites** in v1.
- A successful compile or launch is **not** evidence for overlay, accessibility, login-item, IPC-security, or Sparkle update behavior—those need Mac integration or manual acceptance.
- Do not duplicate portable tests into a parallel `TestsLinux` tree; keep tests with their owning feature and gate Apple APIs explicitly.
- Keep XCUITest coverage minimal smokes only; broad UI automation is out of scope.

## Review checklist

1. New logic has a home in the table above (or a justified new suite name).
2. Linux-runnable cases stay free of AppKit/UIKit/SwiftUI imports.
3. Async tests use injected clock / confirmations; no wall-clock sleeps.
4. No screenshot assertions or golden image tooling added.
5. UI changes get at most launch/menu smokes unless Mac acceptance is explicitly required.
