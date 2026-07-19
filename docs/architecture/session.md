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

| State | Required data |
|---|---|
| `focus` | `cycleID`, `focusStartedAt`, `warningStartsAt`, `breakDueAt` |
| `warning` | same cycle/deadlines plus `warningStartedAt` |
| `break` | `cycleID`, `breakStartedAt`, `breakEndsAt`, trigger (`scheduled`, `startNow`, `cli`, `catchUp`) |
| `paused` | frozen prior state, `pausedAt`, exact remaining durations |

A first launch with no snapshot starts `focus` at `now`.

## Transitions and edge semantics

- At `focusStartedAt + 19m50s`, `focus → warning`.
- At the break due time, `warning → break`; the break gets a full 20 seconds.
- Warning `Start now` begins a full break immediately.
- Warning `Snooze +1m` sets `breakDueAt = now + 60s`, returns to `focus`, and
  re-enters warning 10 seconds before the new due time. Repeated snoozes are
  allowed; do not invent a cap.
- Warning `Skip` records the break as skipped and starts a fresh 20-minute
  focus cycle.
- Break `Skip`, including the emergency overlay action, records the break as
  skipped and starts a fresh focus cycle.
- Natural break completion records completion and starts a fresh focus cycle at
  `breakEndsAt`.
- Pause is legal during focus, warning, or break; it hides warning/overlay
  presentation and freezes exact remaining durations. Paused time never counts.
- Resume rebuilds deadlines from the frozen durations. A paused snapshot remains
  paused across relaunch.
- The CLI `start` bootstraps a missing runtime and may cold-launch the app. It is
  a successful no-op when an active runtime already exists and is rejected with
  “use resume” when the persisted runtime is paused.
- `trigger-break` starts a full break from focus or warning and is a successful
  no-op if already in break. From a paused state it explicitly abandons the
  frozen phase, resumes the schedule, and starts an active 20-second break so
  the overlay appears immediately.
- Reconcile before every wake, restore, and command so stale warning actions
  cannot mutate a state that has already advanced.

Wall-clock deadlines count elapsed time through screen lock, idle time, sleep,
and app downtime; only explicit pause excludes time. If a persisted
focus/warning deadline is overdue at restore or wake, start one full catch-up
break at the current `now`. Do not fabricate repeated cycles or outcome history
for every missed interval. If a persisted break has already ended, record its
completion once, derive the next focus, and then apply the same bounded
catch-up rule. Store UTC instants; timezone changes do not affect elapsed time.
A backward system-clock jump delays a future deadline but never creates reverse
transitions.

## Isolation rules

- No global clock reads inside the reducer.
- No real timers, sleeps, persistence, or Apple UI imports in `FocusSession`.
- Wall-clock elapsed time drives progress except during explicit pause.
- Persistence stores a transactional runtime snapshot plus a minimal outcome log;
  the session module emits events, it does not write SQLite itself.

## Time and persistence seams

- `WallClock.now` is injected.
- `WakeScheduler` schedules the next absolute deadline and is replaceable by a
  manual scheduler.
- Tests advance a manual clock; no test uses real `Task.sleep`.
- `FocusEventStore.commit(snapshot:events:)` writes the new runtime snapshot and
  events in one transaction.
- SQLite has only `schema_meta`, one-row `runtime_snapshot`, and append-only
  `outcome_events`.
- Runtime starts from the snapshot. This is **not** event sourcing; there is no
  replay engine, analytics query layer, or stats schema.

Minimal outcome events are `sessionStarted`, `breakStarted`, `breakCompleted`,
`breakSnoozed`, and `breakSkipped`. Each stores `schemaVersion`, monotonic
sequence, event/cycle IDs, UTC timestamp, source (`timer`, `warning`, `cli`,
`recovery`), and only event-specific fields such as the 60-second snooze
deadline. Pause/resume remain runtime transitions, not required
behavioral-outcome events.
