import Foundation

/// Deterministic focus-session reducer/reconciler.
///
/// Always pass an injected `now`. The reducer never reads a global clock, starts
/// timers, sleeps, or touches persistence.
public enum SessionReducer: Sendable {
  /// Reduce `intent` against an optional runtime at absolute wall-clock `now`.
  ///
  /// Reconciliation runs before every command so stale actions cannot mutate a
  /// phase that has already advanced.
  public static func reduce(
    runtime: SessionRuntime?,
    intent: SessionIntent,
    at now: Date,
    ids: inout IdentifierFactory
  ) -> SessionReduction {
    var events: [OutcomeEvent] = []
    var sequence = runtime?.lastSequence ?? 0

    let bootstrapped: SessionRuntime
    if let runtime {
      bootstrapped = runtime
    } else {
      let started = startFocusCycle(
        at: now, source: bootstrapSource(for: intent), ids: &ids, sequence: &sequence,
        events: &events)
      bootstrapped = SessionRuntime(phase: .focus(started), lastSequence: sequence)
    }

    let reconciled = reconcile(
      runtime: bootstrapped,
      at: now,
      ids: &ids,
      sequence: &sequence,
      events: &events
    )

    let applied = applyIntent(
      intent,
      to: reconciled,
      at: now,
      ids: &ids,
      sequence: &sequence,
      events: &events,
      bootstrappedFromNil: runtime == nil
    )

    var finalRuntime = applied.runtime
    finalRuntime.lastSequence = sequence
    return SessionReduction(
      runtime: finalRuntime,
      events: events,
      presentation: presentation(for: finalRuntime.phase),
      commandResult: applied.commandResult
    )
  }

  // MARK: - Reconcile

  private static func reconcile(
    runtime: SessionRuntime,
    at now: Date,
    ids: inout IdentifierFactory,
    sequence: inout UInt64,
    events: inout [OutcomeEvent]
  ) -> SessionRuntime {
    switch runtime.phase {
    case .paused:
      // Paused snapshots stay paused across relaunch; wall time does not count.
      return runtime

    case .focus(let focus):
      return reconcileFocus(
        focus,
        at: now,
        lastSequence: runtime.lastSequence,
        ids: &ids,
        sequence: &sequence,
        events: &events
      )

    case .warning(let warning):
      return reconcileWarning(
        warning,
        at: now,
        lastSequence: runtime.lastSequence,
        ids: &ids,
        sequence: &sequence,
        events: &events
      )

    case .breakTime(let breakPhase):
      return reconcileBreak(
        breakPhase,
        at: now,
        lastSequence: runtime.lastSequence,
        ids: &ids,
        sequence: &sequence,
        events: &events
      )
    }
  }

  private static func reconcileFocus(
    _ focus: FocusPhase,
    at now: Date,
    lastSequence: UInt64,
    ids: inout IdentifierFactory,
    sequence: inout UInt64,
    events: inout [OutcomeEvent]
  ) -> SessionRuntime {
    if now < focus.warningStartsAt {
      return SessionRuntime(phase: .focus(focus), lastSequence: lastSequence)
    }
    if now < focus.breakDueAt {
      let warning = WarningPhase(
        cycleID: focus.cycleID,
        focusStartedAt: focus.focusStartedAt,
        warningStartsAt: focus.warningStartsAt,
        breakDueAt: focus.breakDueAt,
        warningStartedAt: focus.warningStartsAt
      )
      return SessionRuntime(phase: .warning(warning), lastSequence: lastSequence)
    }
    return beginCatchUpOrScheduledBreak(
      cycleID: focus.cycleID,
      dueAt: focus.breakDueAt,
      at: now,
      lastSequence: lastSequence,
      ids: &ids,
      sequence: &sequence,
      events: &events
    )
  }

  private static func reconcileWarning(
    _ warning: WarningPhase,
    at now: Date,
    lastSequence: UInt64,
    ids: inout IdentifierFactory,
    sequence: inout UInt64,
    events: inout [OutcomeEvent]
  ) -> SessionRuntime {
    // Backward clock jumps must not reverse warning → focus.
    if now < warning.breakDueAt {
      return SessionRuntime(phase: .warning(warning), lastSequence: lastSequence)
    }
    return beginCatchUpOrScheduledBreak(
      cycleID: warning.cycleID,
      dueAt: warning.breakDueAt,
      at: now,
      lastSequence: lastSequence,
      ids: &ids,
      sequence: &sequence,
      events: &events
    )
  }

  private static func reconcileBreak(
    _ breakPhase: BreakPhase,
    at now: Date,
    lastSequence: UInt64,
    ids: inout IdentifierFactory,
    sequence: inout UInt64,
    events: inout [OutcomeEvent]
  ) -> SessionRuntime {
    // Backward clock jumps must not reverse out of an active break.
    if now < breakPhase.breakEndsAt {
      return SessionRuntime(phase: .breakTime(breakPhase), lastSequence: lastSequence)
    }

    appendEvent(
      .breakCompleted,
      cycleID: breakPhase.cycleID,
      at: breakPhase.breakEndsAt,
      source: .timer,
      ids: &ids,
      sequence: &sequence,
      events: &events
    )

    let focus = startFocusCycle(
      at: breakPhase.breakEndsAt,
      source: .timer,
      ids: &ids,
      sequence: &sequence,
      events: &events
    )

    // Bounded catch-up: at most one catch-up break after deriving the next focus.
    if now >= focus.breakDueAt {
      return beginBreak(
        cycleID: focus.cycleID,
        startedAt: now,
        trigger: .catchUp,
        source: .recovery,
        lastSequence: lastSequence,
        ids: &ids,
        sequence: &sequence,
        events: &events
      )
    }
    if now >= focus.warningStartsAt {
      let warning = WarningPhase(
        cycleID: focus.cycleID,
        focusStartedAt: focus.focusStartedAt,
        warningStartsAt: focus.warningStartsAt,
        breakDueAt: focus.breakDueAt,
        warningStartedAt: focus.warningStartsAt
      )
      return SessionRuntime(phase: .warning(warning), lastSequence: sequence)
    }
    return SessionRuntime(phase: .focus(focus), lastSequence: sequence)
  }

  private static func beginCatchUpOrScheduledBreak(
    cycleID: UUID,
    dueAt: Date,
    at now: Date,
    lastSequence: UInt64,
    ids: inout IdentifierFactory,
    sequence: inout UInt64,
    events: inout [OutcomeEvent]
  ) -> SessionRuntime {
    if now > dueAt {
      return beginBreak(
        cycleID: cycleID,
        startedAt: now,
        trigger: .catchUp,
        source: .recovery,
        lastSequence: lastSequence,
        ids: &ids,
        sequence: &sequence,
        events: &events
      )
    }
    return beginBreak(
      cycleID: cycleID,
      startedAt: dueAt,
      trigger: .scheduled,
      source: .timer,
      lastSequence: lastSequence,
      ids: &ids,
      sequence: &sequence,
      events: &events
    )
  }

  // MARK: - Intents

  private struct IntentApplication {
    var runtime: SessionRuntime
    var commandResult: SessionCommandResult
  }

  private static func applyIntent(
    _ intent: SessionIntent,
    to runtime: SessionRuntime,
    at now: Date,
    ids: inout IdentifierFactory,
    sequence: inout UInt64,
    events: inout [OutcomeEvent],
    bootstrappedFromNil: Bool
  ) -> IntentApplication {
    switch intent {
    case .reconcile:
      return IntentApplication(runtime: runtime, commandResult: .performed)

    case .start:
      return applyStart(
        runtime: runtime,
        bootstrappedFromNil: bootstrappedFromNil
      )

    case .startNow:
      return applyStartNow(
        runtime: runtime,
        at: now,
        ids: &ids,
        sequence: &sequence,
        events: &events
      )

    case .snooze(let source):
      return applySnooze(
        runtime: runtime,
        at: now,
        source: source,
        ids: &ids,
        sequence: &sequence,
        events: &events
      )

    case .skip(let source):
      return applySkip(
        runtime: runtime,
        at: now,
        source: source,
        ids: &ids,
        sequence: &sequence,
        events: &events
      )

    case .pause:
      return applyPause(runtime: runtime, at: now)

    case .resume:
      return applyResume(runtime: runtime, at: now)

    case .triggerBreak:
      return applyTriggerBreak(
        runtime: runtime,
        at: now,
        ids: &ids,
        sequence: &sequence,
        events: &events
      )
    }
  }

  private static func applyStart(
    runtime: SessionRuntime,
    bootstrappedFromNil: Bool
  ) -> IntentApplication {
    switch runtime.phase {
    case .paused:
      return IntentApplication(runtime: runtime, commandResult: .rejected(.useResume))
    case .focus, .warning, .breakTime:
      if bootstrappedFromNil {
        return IntentApplication(runtime: runtime, commandResult: .performed)
      }
      return IntentApplication(runtime: runtime, commandResult: .noop)
    }
  }

  private static func applyStartNow(
    runtime: SessionRuntime,
    at now: Date,
    ids: inout IdentifierFactory,
    sequence: inout UInt64,
    events: inout [OutcomeEvent]
  ) -> IntentApplication {
    switch runtime.phase {
    case .warning(let warning):
      let next = beginBreak(
        cycleID: warning.cycleID,
        startedAt: now,
        trigger: .startNow,
        source: .warning,
        lastSequence: runtime.lastSequence,
        ids: &ids,
        sequence: &sequence,
        events: &events
      )
      return IntentApplication(runtime: next, commandResult: .performed)
    case .focus, .breakTime, .paused:
      return IntentApplication(runtime: runtime, commandResult: .rejected(.invalidForPhase))
    }
  }

  private static func applySnooze(
    runtime: SessionRuntime,
    at now: Date,
    source: OutcomeEventSource,
    ids: inout IdentifierFactory,
    sequence: inout UInt64,
    events: inout [OutcomeEvent]
  ) -> IntentApplication {
    switch runtime.phase {
    case .warning(let warning):
      let breakDueAt = now.addingTimeInterval(FocusPolicy.snoozeDuration)
      let warningStartsAt = breakDueAt.addingTimeInterval(-FocusPolicy.warningDuration)
      let focus = FocusPhase(
        cycleID: warning.cycleID,
        focusStartedAt: warning.focusStartedAt,
        warningStartsAt: warningStartsAt,
        breakDueAt: breakDueAt
      )
      appendEvent(
        .breakSnoozed(deadline: breakDueAt),
        cycleID: warning.cycleID,
        at: now,
        source: source,
        ids: &ids,
        sequence: &sequence,
        events: &events
      )
      return IntentApplication(
        runtime: SessionRuntime(phase: .focus(focus), lastSequence: sequence),
        commandResult: .performed
      )
    case .focus, .breakTime, .paused:
      return IntentApplication(runtime: runtime, commandResult: .rejected(.invalidForPhase))
    }
  }

  private static func applySkip(
    runtime: SessionRuntime,
    at now: Date,
    source: OutcomeEventSource,
    ids: inout IdentifierFactory,
    sequence: inout UInt64,
    events: inout [OutcomeEvent]
  ) -> IntentApplication {
    switch runtime.phase {
    case .warning(let warning):
      appendEvent(
        .breakSkipped,
        cycleID: warning.cycleID,
        at: now,
        source: source,
        ids: &ids,
        sequence: &sequence,
        events: &events
      )
      let focus = startFocusCycle(
        at: now,
        source: source,
        ids: &ids,
        sequence: &sequence,
        events: &events
      )
      return IntentApplication(
        runtime: SessionRuntime(phase: .focus(focus), lastSequence: sequence),
        commandResult: .performed
      )

    case .breakTime(let breakPhase):
      appendEvent(
        .breakSkipped,
        cycleID: breakPhase.cycleID,
        at: now,
        source: source,
        ids: &ids,
        sequence: &sequence,
        events: &events
      )
      let focus = startFocusCycle(
        at: now,
        source: source,
        ids: &ids,
        sequence: &sequence,
        events: &events
      )
      return IntentApplication(
        runtime: SessionRuntime(phase: .focus(focus), lastSequence: sequence),
        commandResult: .performed
      )

    case .focus, .paused:
      return IntentApplication(runtime: runtime, commandResult: .rejected(.invalidForPhase))
    }
  }

  private static func applyPause(
    runtime: SessionRuntime,
    at now: Date
  ) -> IntentApplication {
    switch runtime.phase {
    case .paused:
      return IntentApplication(runtime: runtime, commandResult: .noop)

    case .focus(let focus):
      let remaining = PausedRemaining.focus(
        untilWarning: focus.warningStartsAt.timeIntervalSince(now),
        untilBreak: focus.breakDueAt.timeIntervalSince(now)
      )
      let paused = PausedPhase(
        frozen: .focus(focus),
        pausedAt: now,
        remaining: remaining
      )
      return IntentApplication(
        runtime: SessionRuntime(phase: .paused(paused), lastSequence: runtime.lastSequence),
        commandResult: .performed
      )

    case .warning(let warning):
      let remaining = PausedRemaining.warning(
        untilBreak: warning.breakDueAt.timeIntervalSince(now)
      )
      let paused = PausedPhase(
        frozen: .warning(warning),
        pausedAt: now,
        remaining: remaining
      )
      return IntentApplication(
        runtime: SessionRuntime(phase: .paused(paused), lastSequence: runtime.lastSequence),
        commandResult: .performed
      )

    case .breakTime(let breakPhase):
      let remaining = PausedRemaining.breakTime(
        untilEnd: breakPhase.breakEndsAt.timeIntervalSince(now)
      )
      let paused = PausedPhase(
        frozen: .breakTime(breakPhase),
        pausedAt: now,
        remaining: remaining
      )
      return IntentApplication(
        runtime: SessionRuntime(phase: .paused(paused), lastSequence: runtime.lastSequence),
        commandResult: .performed
      )
    }
  }

  private static func applyResume(
    runtime: SessionRuntime,
    at now: Date
  ) -> IntentApplication {
    switch runtime.phase {
    case .focus, .warning, .breakTime:
      return IntentApplication(runtime: runtime, commandResult: .noop)

    case .paused(let paused):
      let phase = rebuildPhase(from: paused, at: now)
      return IntentApplication(
        runtime: SessionRuntime(phase: phase, lastSequence: runtime.lastSequence),
        commandResult: .performed
      )
    }
  }

  private static func applyTriggerBreak(
    runtime: SessionRuntime,
    at now: Date,
    ids: inout IdentifierFactory,
    sequence: inout UInt64,
    events: inout [OutcomeEvent]
  ) -> IntentApplication {
    switch runtime.phase {
    case .breakTime:
      return IntentApplication(runtime: runtime, commandResult: .noop)

    case .focus(let focus):
      let next = beginBreak(
        cycleID: focus.cycleID,
        startedAt: now,
        trigger: .cli,
        source: .cli,
        lastSequence: runtime.lastSequence,
        ids: &ids,
        sequence: &sequence,
        events: &events
      )
      return IntentApplication(runtime: next, commandResult: .performed)

    case .warning(let warning):
      let next = beginBreak(
        cycleID: warning.cycleID,
        startedAt: now,
        trigger: .cli,
        source: .cli,
        lastSequence: runtime.lastSequence,
        ids: &ids,
        sequence: &sequence,
        events: &events
      )
      return IntentApplication(runtime: next, commandResult: .performed)

    case .paused(let paused):
      // Abandon the frozen phase, resume the schedule as an immediate break.
      let cycleID = SessionPhase.paused(paused).cycleID
      let next = beginBreak(
        cycleID: cycleID,
        startedAt: now,
        trigger: .cli,
        source: .cli,
        lastSequence: runtime.lastSequence,
        ids: &ids,
        sequence: &sequence,
        events: &events
      )
      return IntentApplication(runtime: next, commandResult: .performed)
    }
  }

  // MARK: - Builders

  private static func bootstrapSource(for intent: SessionIntent) -> OutcomeEventSource {
    switch intent {
    case .start, .triggerBreak:
      return .cli
    case .reconcile, .startNow, .pause, .resume:
      return .timer
    case .snooze(let source), .skip(let source):
      return source
    }
  }

  private static func startFocusCycle(
    at start: Date,
    source: OutcomeEventSource,
    ids: inout IdentifierFactory,
    sequence: inout UInt64,
    events: inout [OutcomeEvent]
  ) -> FocusPhase {
    let cycleID = ids.next()
    let warningStartsAt = start.addingTimeInterval(FocusPolicy.focusUntilWarning)
    let breakDueAt = start.addingTimeInterval(FocusPolicy.focusDuration)
    let focus = FocusPhase(
      cycleID: cycleID,
      focusStartedAt: start,
      warningStartsAt: warningStartsAt,
      breakDueAt: breakDueAt
    )
    appendEvent(
      .sessionStarted,
      cycleID: cycleID,
      at: start,
      source: source,
      ids: &ids,
      sequence: &sequence,
      events: &events
    )
    return focus
  }

  private static func beginBreak(
    cycleID: UUID,
    startedAt: Date,
    trigger: BreakTrigger,
    source: OutcomeEventSource,
    lastSequence: UInt64,
    ids: inout IdentifierFactory,
    sequence: inout UInt64,
    events: inout [OutcomeEvent]
  ) -> SessionRuntime {
    let endsAt = startedAt.addingTimeInterval(FocusPolicy.breakDuration)
    let phase = BreakPhase(
      cycleID: cycleID,
      breakStartedAt: startedAt,
      breakEndsAt: endsAt,
      trigger: trigger
    )
    appendEvent(
      .breakStarted(trigger: trigger),
      cycleID: cycleID,
      at: startedAt,
      source: source,
      ids: &ids,
      sequence: &sequence,
      events: &events
    )
    return SessionRuntime(phase: .breakTime(phase), lastSequence: max(lastSequence, sequence))
  }

  private static func rebuildPhase(from paused: PausedPhase, at now: Date) -> SessionPhase {
    switch (paused.frozen, paused.remaining) {
    case (.focus(let focus), .focus(let untilWarning, let untilBreak)):
      let warningStartsAt = now.addingTimeInterval(untilWarning)
      let breakDueAt = now.addingTimeInterval(untilBreak)
      let focusStartedAt = breakDueAt.addingTimeInterval(-FocusPolicy.focusDuration)
      return .focus(
        FocusPhase(
          cycleID: focus.cycleID,
          focusStartedAt: focusStartedAt,
          warningStartsAt: warningStartsAt,
          breakDueAt: breakDueAt
        )
      )

    case (.warning(let warning), .warning(let untilBreak)):
      let breakDueAt = now.addingTimeInterval(untilBreak)
      let warningStartsAt = breakDueAt.addingTimeInterval(-FocusPolicy.warningDuration)
      let focusStartedAt = breakDueAt.addingTimeInterval(-FocusPolicy.focusDuration)
      return .warning(
        WarningPhase(
          cycleID: warning.cycleID,
          focusStartedAt: focusStartedAt,
          warningStartsAt: warningStartsAt,
          breakDueAt: breakDueAt,
          warningStartedAt: now
        )
      )

    case (.breakTime(let breakPhase), .breakTime(let untilEnd)):
      let breakEndsAt = now.addingTimeInterval(untilEnd)
      let breakStartedAt = breakEndsAt.addingTimeInterval(-FocusPolicy.breakDuration)
      return .breakTime(
        BreakPhase(
          cycleID: breakPhase.cycleID,
          breakStartedAt: breakStartedAt,
          breakEndsAt: breakEndsAt,
          trigger: breakPhase.trigger
        )
      )

    case (.focus, .warning), (.focus, .breakTime),
      (.warning, .focus), (.warning, .breakTime),
      (.breakTime, .focus), (.breakTime, .warning):
      // Pause always writes matching remainders; keep the snapshot if mismatched.
      return .paused(paused)
    }
  }

  private static func appendEvent(
    _ kind: OutcomeEventKind,
    cycleID: UUID,
    at timestamp: Date,
    source: OutcomeEventSource,
    ids: inout IdentifierFactory,
    sequence: inout UInt64,
    events: inout [OutcomeEvent]
  ) {
    sequence += 1
    events.append(
      OutcomeEvent(
        sequence: sequence,
        id: ids.next(),
        cycleID: cycleID,
        timestamp: timestamp,
        source: source,
        kind: kind
      )
    )
  }

  private static func presentation(for phase: SessionPhase) -> PresentationDirective {
    switch phase {
    case .focus:
      return .none
    case .warning:
      return .showWarning
    case .breakTime:
      return .showBreakOverlay
    case .paused:
      return .hideWhilePaused
    }
  }
}
