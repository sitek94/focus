---
summary: "Fixed focus/warning/break/snooze state machine, injected time, and persistence event semantics."
read_when:
  - "Changing timer lengths, states, or transitions"
  - "Implementing or testing FocusSession"
  - "Wiring persistence or UI to session outcomes"
---

# Session architecture

`FocusSession` is a deterministic reducer over immutable `Sendable` values. It
receives `now` and an intent, and returns the next state, outcome events, and
presentation directives.

## Fixed policy (not configurable)

| Constant | Seconds |
|---|---:|
| Focus | 1200 |
| Warning | final 10 of focus |
| Break | 20 |
| Snooze | 60 from action time |

These values must never appear as preferences, plist keys, defaults, CLI options,
or settings controls.

## Isolation rules

- No global clock reads inside the reducer.
- No real timers, sleeps, persistence, or Apple UI imports in `FocusSession`.
- Wall-clock elapsed time drives progress except during explicit pause.
- Persistence stores a transactional runtime snapshot plus a minimal outcome log;
  the session module emits events, it does not write SQLite itself.

See `PLAN.md` §7 for the full transition table and edge semantics.
