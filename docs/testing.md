---
summary: "Linux-authoritative SwiftPM test lanes, Mac CI integration/smoke targets, and manual limits."
read_when:
  - "Adding or naming a test target or acceptance case"
  - "Deciding whether a behavior must pass on Linux"
  - "Writing XCUITest smoke coverage"
---

# Testing

## Linux-authoritative (SwiftPM)

| Suite | Focus |
|---|---|
| `FocusSessionTests` | Fixed timing, transitions, pause/resume, reconciliation |
| `FocusPersistenceIntegrationTests` | SQLite snapshot/event atomicity |
| `FocusControlTests` | Framing, DTOs, protocol validation |
| `FocusCLIIntegrationTests` | Real Linux socket fixture + CLI subprocess |
| `FocusPlatformGatingTests` | Platform seams that must stay portable |

Run all with `make test-linux`, or focused filters via `make test-session`,
`test-persistence`, `test-control`, `test-cli`, `test-platform-gating`.

## Mac CI

- `FocusMacIntegrationTests` — Darwin socket, `getpeereid`, adapters.
- `FocusMacUITests` / `FocusIOSUITests` — minimal launch smokes only.
- No screenshot/visual-regression tooling in v1.

## Manual Mac only

Multi-display overlays, Dockless no-flash, login-item enable/revoke, VoiceOver,
App Translocation CLI install, and signed Sparkle update paths require an
interactive or credentialed Mac. They are not Linux-provable.
