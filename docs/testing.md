---
summary: "Linux-authoritative SwiftPM test lanes, Mac CI integration/smoke targets, and manual limits."
read_when:
  - "Adding or naming a test target or suite"
  - "Deciding whether a behavior must pass on Linux"
  - "Writing XCUITest smoke coverage"
---

# Testing

Audience: contributors adding or reviewing tests.

Scope: which suites run where, and what Linux cannot prove. Non-scope: product
acceptance criteria for placeholder features.

## Linux-authoritative (SwiftPM)

| Suite | Makefile filter |
|---|---|
| `FocusSessionTests` | `make test-session` |
| `FocusPersistenceIntegrationTests` | `make test-persistence` |
| `FocusControlTests` | `make test-control` |
| `FocusCLIIntegrationTests` | `make test-cli` |
| `FocusPlatformGatingTests` | `make test-platform-gating` |

Run the full portable set with `make test-linux`. Prefer Swift Testing
(`@Test`, `#expect` / `#require`) for these suites. Inject clocks and clients;
do not use real `Task.sleep` in portable tests.

## Mac CI

- `FocusMacIntegrationTests` — Darwin socket and platform adapters.
- `FocusMacUITests` / `FocusIOSUITests` — minimal launch smokes only.
- No screenshot or visual-regression tooling.

A successful compile or launch is not evidence for overlay, accessibility,
login-item, IPC-security, or Sparkle update behavior. Those need Mac
integration or manual acceptance.

## Manual Mac only

Multi-display overlays, Dockless no-flash, login-item enable/revoke, VoiceOver,
App Translocation CLI install, and signed Sparkle update paths need an
interactive or credentialed Mac. They are not Linux-provable.

## Related

- [Repository layout](./layout.md)
- [`AGENTS.md`](../AGENTS.md) — proof boundary and command index
- [`.agents/skills/focus-testing/SKILL.md`](../.agents/skills/focus-testing/SKILL.md)
