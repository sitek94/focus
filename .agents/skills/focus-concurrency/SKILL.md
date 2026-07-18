---
name: focus-concurrency
description: >
  Focus Swift 6 concurrency: isolation map, injected clock, cancellation, test
  commands, and ban on unsafe escapes. Use when editing session/runtime,
  persistence, IPC, wake scheduling, or concurrency diagnostics.
upstream: https://github.com/AvdLee/Swift-Concurrency-Agent-Skill
commit: 0d472de78225d2875283c35eaca1c060c493bdb3
source_paths:
  - swift-concurrency/SKILL.md
  - swift-concurrency/references/actors.md
  - swift-concurrency/references/sendable.md
  - swift-concurrency/references/tasks.md
  - swift-concurrency/references/testing.md
  - swift-concurrency/references/threading.md
license: MIT
disposition: adapted
---

# Focus Concurrency

## Provenance

| Field | Value |
|---|---|
| Upstream | https://github.com/AvdLee/Swift-Concurrency-Agent-Skill |
| Commit | `0d472de78225d2875283c35eaca1c060c493bdb3` |
| License | MIT |
| Disposition | **adapted** (not copied) |
| Source paths | `swift-concurrency/SKILL.md`; `references/actors.md`; `sendable.md`; `tasks.md`; `testing.md`; `threading.md` |

Materially rewritten around Focus’s isolation map (`PLAN.md` §11), injected clock, and stricter unsafe-escape policy. Upstream Core Data / course links / broad migration dumps are omitted.

## Project settings (assume confirmed)

- Swift 6 language mode, strict concurrency on all SwiftPM and Xcode targets.
- Do not guess Xcode “Approachable Concurrency” defaults; read `Package.swift` / project settings when diagnosing.

## Isolation map

| Owner / value | Isolation | Notes |
|---|---|---|
| `FocusSession` reducer/state/events | immutable `Sendable` values + pure functions | No hidden mutable owner |
| App runtime store | `@MainActor` | Sole authority for session + presentation directives |
| SwiftUI views / menu commands | `@MainActor` | Render state; send intents only |
| Warning / overlay coordinators | `@MainActor` | AppKit/SwiftUI window state |
| SQLite connection / store | `actor` | One handle; transaction boundary |
| Wake scheduler | `actor` | Owns/cancels the single next-deadline task |
| IPC listener | `actor` | Accept/read/write; hop to `@MainActor` for mutations |
| CLI client | immutable value + async ops | No process-global mutable state |
| ServiceManagement / Sparkle adapters | `@MainActor` unless API proves otherwise | Serialize UI/status calls |

## Hard bans

Do **not** introduce:

- `@unchecked Sendable`
- `nonisolated(unsafe)`
- `MainActor.assumeIsolated`
- `@preconcurrency` imports/annotations to silence races
- `Task.detached` for state mutation
- mutable global singletons

A genuine framework-bound exception needs a local written invariant, owner, tracking issue, and deletion condition—not “to make it compile.”

## Clock, wake, cancellation

- Inject `WallClock.now`. Production uses wall time; tests use a manual clock.
- `WakeScheduler` schedules the **one** next absolute deadline and cancels/replaces on reconcile.
- Prefer structured concurrency. Unstructured `Task` only at actor/UI edges with clear lifetime ownership.
- Separate waiting from UI mutation: sleep/deadline work stays off the main actor when possible; apply presentation updates on `@MainActor`.
- Tests advance the manual clock; **never** use real `Task.sleep` in unit/integration tests.

## Smallest safe fixes

| Symptom | Prefer |
|---|---|
| UI state crossed actors | Keep on `@MainActor` store |
| Shared DB mutation | Stay inside the SQLite actor; commit snapshot+events atomically |
| Sendable hop | Pass immutable values / DTOs, not handles |
| Stale deadline task | Cancel previous wake task, then schedule next |

## Test commands

```bash
make test-linux          # portable Swift Testing suites
make test-session        # FocusSessionTests (clock/reconcile)
make test-persistence    # actor store / transactions
make test-control        # IPC framing + cancellation
make test-cli            # Linux socket fixture + CLI
```

Mac-only concurrency seams (`getpeereid`, AppKit overlays) belong in `FocusMacIntegrationTests`, not Linux.

## Review checklist

1. Change matches the isolation table; no new shared mutable owner.
2. No banned escapes without documented exception.
3. Clock injected; wake task cancelled on supersede.
4. Tests use manual clock / deterministic awaits, not wall sleeps.
