---
name: focus-testing
description: >
  Focus testing router: Swift Testing suites, Linux-authoritative subset,
  XCUITest smokes, and no-screenshot rule. Use when adding, reviewing, or
  migrating Focus tests.
---

# Focus Testing

Routes agents to Focus’s suites and CI boundaries. Details and commands live in
`docs/testing.md` — read it before adding or naming a test target.

## Defaults

- New unit/integration tests: **Swift Testing** (`@Test`, `#expect` / `#require`, structs).
- UI tests: **XCTest** / XCUITest only (Swift Testing has no UI support).
- Swift 6.3 toolchain; treat installed toolchain as authoritative.
- Parallel-safe tests; inject clocks/clients; no real `Task.sleep` in portable suites.
- Prefer parameterized tests for phase/command matrices without exploding Cartesian products.

## Hard rules

- No screenshot-golden or visual-regression suites in v1.
- A successful compile or launch is not evidence for overlay, accessibility,
  login-item, IPC-security, or Sparkle update behavior — those need Mac
  integration or manual acceptance.
- Do not duplicate portable tests into a parallel `TestsLinux` tree; keep tests
  with their owning feature and gate Apple APIs explicitly.
- Keep XCUITest coverage to minimal smokes; broad UI automation is out of scope.

## Review checklist

1. New logic has a home in `docs/testing.md`'s suite map (or a justified new suite name).
2. Linux-runnable cases stay free of AppKit/UIKit/SwiftUI imports.
3. Async tests use injected clock / confirmations; no wall-clock sleeps.
4. No screenshot assertions or golden image tooling added.
5. UI changes get at most launch/menu smokes unless Mac acceptance is explicitly required.
