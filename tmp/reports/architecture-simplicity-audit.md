# Architecture simplicity audit: first vertical slice

Date: 2026-07-18
Mode: plan only
Scope: assess only whether the proposed first vertical slice is minimal and coherent

## Verdict

**CHANGE**

The current draft is coherent at the timer-loop level, but it is not minimal as a first
vertical slice. It mixes:

- the core product spine,
- future modularization,
- future release/distribution work,
- future iOS work,
- future documentation/skills curation work.

That makes the first slice harder to build, harder to test, and harder to reason about.
The slice should prove one thing only:

> a direct-distributed macOS menu-bar app can own a fixed timer loop, persist enough
> state to survive sleep/relaunch, show a break overlay, and expose a small stable `focus`
> CLI contract.

Anything that does not directly help prove that spine should move out of the first slice.

## Decision table

| Area | Decision | Why |
| --- | --- | --- |
| Target count | **CHANGE** | The draft target graph is too large for a first slice. Separate `FocusPersistence`, `FocusIPC`, `FocusTestSupport`, both iOS targets, and both smoke targets are architectural convenience, not minimum product proof. |
| SQLite + event-sourcing complexity | **CHANGE** | Snapshot plus append-only events plus migrations plus replay semantics is too much for slice one. The first slice needs durable current state, not a local event-history architecture. |
| Preferences ownership | **CHANGE** | Preferences should not be a shared-core concept yet. In this slice, timing is fixed product policy, and platform settings belong to the macOS app layer. |
| CLI required-command semantics | **CHANGE** | The docs conflict, and the current CLI surface is too broad. The first slice needs a small command set with one clear auto-launch rule. |
| Timer boot/catch-up behavior | **KEEP**, with one simplification | The wall-clock reconciliation model is the right one. The simplification is: catch up to the correct current phase, but do not backfill a large historical event stream as a first-slice requirement. |
| Warning vs `trigger-break` naming | **CHANGE** | `warning` is the correct phase name. `trigger-break` is ambiguous and `start` is overloaded. If the CLI exposes the warning action at all, call it `start-now`. |
| Bundle IDs | **CHANGE** | The macOS app should own the base bundle ID in the first slice. Platform suffixes add complexity before they buy anything. |
| Test boundaries | **CHANGE** | The slice should test the portable core and CLI contract on Linux, then do one Mac build lane and a short manual Mac acceptance lane. The current plan spreads proof across too many suites. |
| AppKit seams | **SIMPLIFY** | Keep AppKit only in the macOS adapter for overlay windows and activation edge cases. Do not let AppKit-driven abstractions leak into the shared-core design. |
| App sandbox choice | **CHANGE** | The final plan must choose unsandboxed direct distribution for v1. Otherwise IPC pathing, CLI installation, and Sparkle all become materially different problems. |
| Generated-project fallback | **SIMPLIFY** | Keep one hard gate: if first Mac generate -> build -> archive fails, stop and switch to a native `.xcodeproj`. Do not carry multiple fallback mechanics inside the first-slice plan. |
| Docs / ADR / skill duplication | **CHANGE** | The current doc/ADR/skill set is much too large for slice one and duplicates the same decisions repeatedly. Keep only the minimum durable docs. |

## Corrected minimal target and layout proposal

### Minimal runtime targets

Keep the first slice to **three runtime targets**:

1. `FocusCore` SwiftPM library
   - fixed timer state machine
   - persisted runtime snapshot types
   - command/result DTOs shared by app and CLI
   - simple storage protocol for current state
   - no AppKit, SwiftUI, ServiceManagement, or Sparkle

2. `focus` SwiftPM executable
   - argument parsing
   - human/JSON rendering
   - Unix-socket client
   - `install` helper

3. `FocusMac` app target
   - menu-bar shell
   - one `@MainActor` runtime owner
   - snapshot persistence adapter
   - socket server
   - overlay presenter
   - optional launch-at-login only if the brief insists on it

### Minimal test targets

Keep the first slice to **two portable test targets**:

1. `FocusCoreTests`
   - state transitions
   - pause/resume
   - boot/wake reconciliation
   - persistence round-trips
   - socket envelope encode/decode if those DTOs stay in `FocusCore`

2. `FocusCLITests`
   - human output
   - JSON schema
   - exit-code mapping
   - fake-server integration

### Mac verification lane

Do not create dedicated macOS smoke targets in the first slice unless they are required by
the repo convention later. For the first slice, one Mac CI build lane plus a short manual
acceptance lane is enough:

- generate project
- build `FocusMac`
- manually verify launch, overlay, and CLI-to-app round-trip on a Mac

### Defer from the first slice

Defer these entirely:

- iOS app target
- separate `FocusPersistence` module
- separate `FocusIPC` module
- separate `FocusTestSupport` module
- Sparkle integration
- release workflow
- skills pack
- multiple architecture docs
- multiple ADRs
- XCUITest smoke bundles

### Suggested first-slice layout

```text
/
  Package.swift
  project.yml
  AGENTS.md
  README.md
  docs/
    architecture/
      first-slice.md
    adr/
      0001-first-slice-decisions.md   # optional; keep to one ADR if used at all
  Apps/
    FocusMac/
      FocusMacApp.swift
      Features/
        MenuBar/
        Session/
        Settings/
      Platform/
        Overlay/
        IPC/
        LaunchAtLogin/   # only if truly in-slice
  Sources/
    FocusCore/
      Session/
      Persistence/
      Control/
    focus/
  Tests/
    FocusCoreTests/
    FocusCLITests/
```

## Exact first-slice semantics

The first slice should use exact product semantics, not reusable-looking abstractions that
the product does not yet need.

### Runtime state

Keep exactly four runtime states:

- `focus(cycleID, focusStartedAt, breakDueAt)`
- `warning(cycleID, focusStartedAt, breakDueAt)`
- `break(cycleID, focusStartedAt, breakStartedAt, breakEndsAt, trigger)`
- `paused(previousPhase, frozenRemainingTimes...)`

Keep these locked constants:

- focus = `20m`
- warning = `10s`
- break = `20s`
- snooze = `60s`

Do **not** add:

- `idle`
- `off`
- configurable durations
- generic workflow/action engines
- generic overlay-directive layers beyond what the app actually needs

The app can derive overlay visibility directly from current phase plus deadlines. A separate
domain-level overlay command type is optional at best and not required for this slice.

### Boot and wake

Use one rule set:

1. If there is no persisted snapshot, bootstrap into `focus` at `now`.
2. If state is paused, keep it paused exactly; paused time never catches up.
3. Otherwise reconcile by wall clock until the resulting state contains `now`.
4. Never resurrect an expired warning after wake/relaunch.
5. Backward wall-clock jumps do not synthesize reverse history.

Most important simplification:

- Persist the **resulting snapshot** as the source of truth.
- Do **not** require slice one to append a detailed catch-up history for every missed cycle.

That keeps boot/catch-up behavior deterministic without forcing event-sourcing complexity.

### User actions

Keep exact semantics:

- `pause`
  - legal in `focus`, `warning`, `break`
  - freezes remaining time
  - hides overlay

- `resume`
  - legal only in `paused`
  - rebuilds deadlines from frozen remaining time

- `skip`
  - legal in `warning`, `break`, `paused(warning)`, `paused(break)`
  - starts a new `focus` cycle immediately at `now`

- `startNow`
  - legal only in `warning` and `paused(warning)`
  - starts a full `20s` break immediately

- `snoozeOneMinute`
  - legal only in `warning` and `paused(warning)`
  - keeps the same `cycleID`
  - sets `breakDueAt = now + 60s`

### Persistence

For the first slice, use the smallest persistence story that supports correctness:

- one versioned persisted runtime snapshot
- one app-owned settings store for platform settings

Recommended simplicity rule:

- if a local log is required, treat it as diagnostic append-only output
- do not make it a co-equal source of truth in slice one

That means:

- no event replay requirement for normal startup
- no event-schema-first modeling pressure
- no need for a separate event store protocol just to satisfy architecture aesthetics

SQLite may still be acceptable later, but it should not be justified by event sourcing in
the first slice. If SQLite stays, it should be because it is the simplest way to persist a
current snapshot transactionally, not because the app needs a history architecture on day 1.

## Exact CLI contract for the first slice

The final plan must pick one command vocabulary and stick to it.

### Required commands

Keep only these as the first-slice CLI contract:

- `focus status [--json]`
- `focus open [--json]`
- `focus pause [--json]`
- `focus resume [--json]`
- `focus skip [--json]`
- `focus install [--json]`
- `focus version [--json]`

### Auto-launch rule

Keep exactly one auto-launch rule:

- `open` may launch the app and wait for the socket to become ready
- every other command requires the app to be running already

This avoids accidentally inventing an on/off session mode.

### Commands to defer

Defer these from the first-slice CLI:

- `start-now`
- `snooze`

Reason:

- they are warning-specific UI actions
- they widen the CLI contract without being necessary to prove the vertical slice
- they can be added later without reshaping the architecture

If the brief insists that the CLI must expose one warning action, expose:

- `focus start-now`

and do **not** use:

- `start`
- `trigger-break`

because both are semantically broader than the actual legal action.

## Bundle ID and path simplification

Use this in the first slice:

- macOS app bundle ID: `com.macieksitkowski.focus`

Then derive app-support and IPC paths from that one canonical ID.

Do not spend first-slice complexity on:

- `com.macieksitkowski.focus.mac`
- `com.macieksitkowski.focus.ios`

unless the iOS target remains in-slice, which this audit recommends against.

If iOS returns later, add its suffix then. Do not burden the macOS-first slice with it.

## AppKit seam recommendation

Keep the SwiftUI-first shell, but narrow the AppKit seam aggressively:

- `MenuBarExtra` and settings UI stay SwiftUI
- AppKit is only for:
  - borderless overlay windows
  - per-display placement
  - activation/focus edge cases if Mac testing proves they are needed

Do not define more AppKit-shaped architecture than that in the first slice.

## Sandbox choice

The final plan must make this explicit:

> **First slice is an unsandboxed, direct-distributed macOS app.**

Why this must be explicit:

- Sparkle integration assumes that distribution model
- CLI symlink installation is simpler
- Unix-domain socket placement is simpler
- same-user app/CLI cooperation is simpler

If the app is sandboxed instead, these areas materially change:

- endpoint location
- entitlements
- possible app-group requirement
- CLI/app cooperation model
- update/distribution assumptions

That is too large an unresolved fork to leave ambiguous.

## Generated-project recommendation

Keep XcodeGen if desired, but simplify the fallback policy:

1. Generate with explicit `projectFormat: xcode16_3`
2. Build on the first Mac CI run
3. Archive on the first Mac CI run
4. If that gate fails because of project-format/tooling limits, stop and switch plans to a
   native `.xcodeproj`

Do not keep extra fallback prose about patching generated files or carrying two live
project strategies in the first-slice plan.

## Docs / ADR / skill minimum

The current plan duplicates decisions across too many artifacts.

For the first slice, keep only:

- `README.md`
- `AGENTS.md`
- one short architecture doc: `docs/architecture/first-slice.md`
- optionally one ADR if the repo wants ADRs from day one

Defer:

- separate docs for repository layout, state machine, IPC, overlays, testing, release
- multiple ADRs
- skill curation and licensing workflow docs

Those are valid later, but they are not part of a minimal first vertical slice.

## Dangerous ambiguities the final plan must resolve

These are the plan ambiguities most likely to cause churn or rework if left unresolved.

1. **macOS-only vs macOS+iOS**
   - A first vertical slice should be macOS-only.
   - Keeping iOS in-slice doubles project, CI, bundle-ID, and doc surface for no product proof.

2. **snapshot-first vs event-log-first persistence**
   - Choose one now.
   - If the app only needs durable current state, snapshot-first wins.
   - Do not promise event replay, catch-up event synthesis, and snapshot reconstruction unless the product truly needs that now.

3. **unsandboxed vs sandboxed app**
   - This choice affects IPC, CLI installation, and updater design immediately.
   - It cannot stay implicit.

4. **canonical CLI vocabulary**
   - The current docs conflict between `open`, `start`, `start-now`, and `trigger-break`.
   - Pick one set and make it the only set.

5. **whether warning-only actions belong in the CLI**
   - If not required, defer them.
   - If required, expose `start-now`, not `start` or `trigger-break`.

6. **whether catch-up writes historical events**
   - For a minimal slice, it should not be required.
   - Otherwise the persistence design grows before the product needs it.

7. **whether launch-at-login is truly in-slice**
   - If yes, keep it as a macOS-app concern only.
   - If no, defer it and keep the first slice focused on the timer spine.

8. **what happens if the XcodeGen gate fails**
   - The answer should be: switch plan, not add more workaround architecture.

## Bottom line

The timer-loop semantics are mostly coherent already. The non-minimality comes from trying
to establish the final architecture, final release story, final doc system, and final
module graph in the same first slice.

The corrected first slice should be:

- macOS only
- one shared core target
- one CLI target
- one macOS app target
- snapshot-first persistence
- a narrow CLI contract
- AppKit only at the overlay edge
- unsandboxed direct distribution made explicit
- minimal docs

That is the smallest slice that still proves the real product shape.
