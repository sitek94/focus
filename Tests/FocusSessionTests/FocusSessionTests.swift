import FocusSession
import Foundation
import Testing

@Test
func moduleNameIsFocusSession() {
  #expect(FocusSessionModule.moduleName == "FocusSession")
}

@Test
func fixedPolicyConstantsAreNotConfigurable() {
  #expect(FocusPolicy.focusDuration == 1_200)
  #expect(FocusPolicy.warningDuration == 10)
  #expect(FocusPolicy.breakDuration == 20)
  #expect(FocusPolicy.snoozeDuration == 60)
  #expect(FocusPolicy.focusUntilWarning == 1_190)
  #expect(FocusPolicy.outcomeSchemaVersion == 1)
}

@Test
func firstBootWithNoSnapshotStartsFocusAtNow() {
  var ids = IdentifierFactory.deterministic()
  let clock = ManualClock()
  let result = boot(at: clock.now, ids: &ids)

  let focus = expectFocus(result.runtime)
  #expect(focus.focusStartedAt == clock.now)
  #expect(focus.warningStartsAt == clock.now.addingTimeInterval(1_190))
  #expect(focus.breakDueAt == clock.now.addingTimeInterval(1_200))
  #expect(result.presentation == .none)
  #expect(eventKinds(result.events) == ["sessionStarted"])
  #expect(result.events[0].schemaVersion == 1)
  #expect(result.events[0].sequence == 1)
  #expect(result.events[0].source == .timer)
  #expect(result.events[0].timestamp == clock.now)
}

@Test
func warningBeginsAtNineteenMinutesFiftySeconds() {
  var ids = IdentifierFactory.deterministic()
  var clock = ManualClock()
  let runtime = boot(at: clock.now, ids: &ids).runtime

  clock.advance(by: 1_189)
  let stillFocus = reduce(runtime, .reconcile, at: clock.now, ids: &ids)
  #expect(expectFocus(stillFocus.runtime).cycleID == expectFocus(runtime).cycleID)
  #expect(stillFocus.events.isEmpty)

  clock.advance(by: 1)
  let warned = reduce(stillFocus.runtime, .reconcile, at: clock.now, ids: &ids)
  let warning = expectWarning(warned.runtime)
  #expect(warning.warningStartedAt == warning.warningStartsAt)
  #expect(warning.breakDueAt == warning.focusStartedAt.addingTimeInterval(1_200))
  #expect(warned.presentation == .showWarning)
  #expect(warned.events.isEmpty)
}

@Test
func dueBreakStartsScheduledFullTwentySeconds() {
  var ids = IdentifierFactory.deterministic()
  var clock = ManualClock()
  let runtime = boot(at: clock.now, ids: &ids).runtime
  let focus = expectFocus(runtime)

  clock.set(focus.breakDueAt)
  let due = reduce(runtime, .reconcile, at: clock.now, ids: &ids)
  let breakPhase = expectBreak(due.runtime)
  #expect(breakPhase.trigger == .scheduled)
  #expect(breakPhase.breakStartedAt == focus.breakDueAt)
  #expect(breakPhase.breakEndsAt == focus.breakDueAt.addingTimeInterval(20))
  #expect(due.presentation == .showBreakOverlay)
  #expect(eventKinds(due.events) == ["breakStarted(scheduled)"])
  #expect(due.events[0].source == .timer)
}

@Test
func naturalBreakCompletionStartsFreshFocusAtBreakEndsAt() {
  var ids = IdentifierFactory.deterministic()
  var clock = ManualClock()
  var runtime = boot(at: clock.now, ids: &ids).runtime
  clock.set(expectFocus(runtime).breakDueAt)
  runtime = reduce(runtime, .reconcile, at: clock.now, ids: &ids).runtime
  let breakPhase = expectBreak(runtime)

  clock.set(breakPhase.breakEndsAt)
  let completed = reduce(runtime, .reconcile, at: clock.now, ids: &ids)
  let focus = expectFocus(completed.runtime)
  #expect(focus.focusStartedAt == breakPhase.breakEndsAt)
  #expect(eventKinds(completed.events) == ["breakCompleted", "sessionStarted"])
  #expect(completed.events[0].timestamp == breakPhase.breakEndsAt)
  #expect(focus.cycleID != breakPhase.cycleID)
}

@Test
func repeatedNaturalCyclesDoNotFabricateHistory() {
  var ids = IdentifierFactory.deterministic()
  var clock = ManualClock()
  var runtime = boot(at: clock.now, ids: &ids).runtime
  var completedCycles = 0

  for _ in 0..<3 {
    clock.set(expectFocus(runtime).breakDueAt)
    runtime = reduce(runtime, .reconcile, at: clock.now, ids: &ids).runtime
    let breakPhase = expectBreak(runtime)
    clock.set(breakPhase.breakEndsAt)
    let result = reduce(runtime, .reconcile, at: clock.now, ids: &ids)
    #expect(eventKinds(result.events) == ["breakCompleted", "sessionStarted"])
    runtime = result.runtime
    completedCycles += 1
    #expect(expectFocus(runtime).focusStartedAt == breakPhase.breakEndsAt)
  }

  #expect(completedCycles == 3)
  // boot sessionStarted + 3×(breakStarted + breakCompleted + sessionStarted)
  #expect(runtime.lastSequence == 1 + (3 * 3))
}

@Test
func warningStartNowBeginsFullBreakImmediately() {
  var ids = IdentifierFactory.deterministic()
  var clock = ManualClock()
  var runtime = boot(at: clock.now, ids: &ids).runtime
  clock.advance(by: 1_190)
  runtime = reduce(runtime, .reconcile, at: clock.now, ids: &ids).runtime

  let started = reduce(runtime, .startNow, at: clock.now, ids: &ids)
  let breakPhase = expectBreak(started.runtime)
  #expect(breakPhase.trigger == .startNow)
  #expect(breakPhase.breakStartedAt == clock.now)
  #expect(breakPhase.breakEndsAt == clock.now.addingTimeInterval(20))
  #expect(eventKinds(started.events) == ["breakStarted(startNow)"])
  #expect(started.events[0].source == .warning)
  #expect(started.commandResult == .performed)
}

@Test
func snoozeIsExactlySixtySecondsAndReentersWarningTenSecondsBeforeDue() {
  var ids = IdentifierFactory.deterministic()
  var clock = ManualClock()
  var runtime = boot(at: clock.now, ids: &ids).runtime
  let originalFocusStart = expectFocus(runtime).focusStartedAt
  clock.advance(by: 1_190)
  runtime = reduce(runtime, .reconcile, at: clock.now, ids: &ids).runtime

  let snoozedAt = clock.now
  let snoozed = reduce(runtime, .snooze(source: .warning), at: snoozedAt, ids: &ids)
  let focus = expectFocus(snoozed.runtime)
  #expect(focus.breakDueAt == snoozedAt.addingTimeInterval(60))
  #expect(focus.warningStartsAt == snoozedAt.addingTimeInterval(50))
  #expect(focus.focusStartedAt == originalFocusStart)
  #expect(eventKinds(snoozed.events) == ["breakSnoozed"])
  guard case .breakSnoozed(let deadline) = snoozed.events[0].kind else {
    Issue.record("Expected breakSnoozed")
    return
  }
  #expect(deadline == snoozedAt.addingTimeInterval(60))

  clock.set(focus.warningStartsAt)
  let rewarned = reduce(snoozed.runtime, .reconcile, at: clock.now, ids: &ids)
  #expect(expectWarning(rewarned.runtime).breakDueAt == focus.breakDueAt)

  clock.advance(by: -1)
  let beforeWarning = reduce(
    snoozed.runtime, .reconcile, at: focus.warningStartsAt.addingTimeInterval(-1), ids: &ids)
  #expect(expectFocus(beforeWarning.runtime).breakDueAt == focus.breakDueAt)
}

@Test
func warningSkipRecordsSkipAndStartsFreshFocus() {
  var ids = IdentifierFactory.deterministic()
  var clock = ManualClock()
  var runtime = boot(at: clock.now, ids: &ids).runtime
  let priorCycle = expectFocus(runtime).cycleID
  clock.advance(by: 1_190)
  runtime = reduce(runtime, .reconcile, at: clock.now, ids: &ids).runtime

  let skipped = reduce(runtime, .skip(source: .warning), at: clock.now, ids: &ids)
  let focus = expectFocus(skipped.runtime)
  #expect(focus.cycleID != priorCycle)
  #expect(focus.focusStartedAt == clock.now)
  #expect(eventKinds(skipped.events) == ["breakSkipped", "sessionStarted"])
}

@Test
func breakSkipRecordsSkipAndStartsFreshFocus() {
  var ids = IdentifierFactory.deterministic()
  var clock = ManualClock()
  var runtime = boot(at: clock.now, ids: &ids).runtime
  clock.set(expectFocus(runtime).breakDueAt)
  runtime = reduce(runtime, .reconcile, at: clock.now, ids: &ids).runtime
  let priorCycle = expectBreak(runtime).cycleID

  clock.advance(by: 5)
  let skipped = reduce(runtime, .skip(source: .warning), at: clock.now, ids: &ids)
  let focus = expectFocus(skipped.runtime)
  #expect(focus.cycleID != priorCycle)
  #expect(focus.focusStartedAt == clock.now)
  #expect(eventKinds(skipped.events) == ["breakSkipped", "sessionStarted"])
}

@Test
func skipDuringFocusIsRejected() {
  var ids = IdentifierFactory.deterministic()
  let clock = ManualClock()
  let runtime = boot(at: clock.now, ids: &ids).runtime
  let skipped = reduce(runtime, .skip(source: .cli), at: clock.now, ids: &ids)
  #expect(skipped.commandResult == .rejected(.invalidForPhase))
  #expect(skipped.events.isEmpty)
  #expect(expectFocus(skipped.runtime).cycleID == expectFocus(runtime).cycleID)
}

@Test
func pauseAndResumeInFocusFreezesExactRemainders() {
  var ids = IdentifierFactory.deterministic()
  var clock = ManualClock()
  let runtime = boot(at: clock.now, ids: &ids).runtime
  clock.advance(by: 100)
  let pausedAt = clock.now
  let paused = reduce(runtime, .pause, at: pausedAt, ids: &ids)
  let pausedPhase = expectPaused(paused.runtime)
  #expect(paused.presentation == .hideWhilePaused)
  guard case .focus(let untilWarning, let untilBreak) = pausedPhase.remaining else {
    Issue.record("Expected focus remainders")
    return
  }
  #expect(untilWarning == 1_090)
  #expect(untilBreak == 1_100)

  clock.advance(by: 10_000)
  let resumed = reduce(paused.runtime, .resume, at: clock.now, ids: &ids)
  let focus = expectFocus(resumed.runtime)
  #expect(focus.warningStartsAt == clock.now.addingTimeInterval(1_090))
  #expect(focus.breakDueAt == clock.now.addingTimeInterval(1_100))
}

@Test
func pauseAndResumeInWarning() {
  var ids = IdentifierFactory.deterministic()
  var clock = ManualClock()
  var runtime = boot(at: clock.now, ids: &ids).runtime
  clock.advance(by: 1_190)
  runtime = reduce(runtime, .reconcile, at: clock.now, ids: &ids).runtime

  clock.advance(by: 3)
  let paused = reduce(runtime, .pause, at: clock.now, ids: &ids)
  guard case .warning(let untilBreak) = expectPaused(paused.runtime).remaining else {
    Issue.record("Expected warning remainders")
    return
  }
  #expect(untilBreak == 7)

  clock.advance(by: 500)
  let resumed = reduce(paused.runtime, .resume, at: clock.now, ids: &ids)
  let warning = expectWarning(resumed.runtime)
  #expect(warning.breakDueAt == clock.now.addingTimeInterval(7))
  #expect(resumed.presentation == .showWarning)
}

@Test
func pauseAndResumeInBreak() {
  var ids = IdentifierFactory.deterministic()
  var clock = ManualClock()
  var runtime = boot(at: clock.now, ids: &ids).runtime
  clock.set(expectFocus(runtime).breakDueAt)
  runtime = reduce(runtime, .reconcile, at: clock.now, ids: &ids).runtime

  clock.advance(by: 8)
  let paused = reduce(runtime, .pause, at: clock.now, ids: &ids)
  guard case .breakTime(let untilEnd) = expectPaused(paused.runtime).remaining else {
    Issue.record("Expected break remainders")
    return
  }
  #expect(untilEnd == 12)

  clock.advance(by: 1_000)
  let resumed = reduce(paused.runtime, .resume, at: clock.now, ids: &ids)
  let breakPhase = expectBreak(resumed.runtime)
  #expect(breakPhase.breakEndsAt == clock.now.addingTimeInterval(12))
  #expect(breakPhase.trigger == .scheduled)
  #expect(resumed.presentation == .showBreakOverlay)
}

@Test
func longPauseNeverCountsPausedWallTime() {
  var ids = IdentifierFactory.deterministic()
  var clock = ManualClock()
  var runtime = boot(at: clock.now, ids: &ids).runtime
  clock.advance(by: 200)
  runtime = reduce(runtime, .pause, at: clock.now, ids: &ids).runtime

  clock.advance(by: 86_400)
  // Still paused across "relaunch"/reconcile.
  let stillPaused = reduce(runtime, .reconcile, at: clock.now, ids: &ids)
  #expect(expectPaused(stillPaused.runtime).pausedAt == runtime.phase.pausedAtOrNil)
  #expect(stillPaused.events.isEmpty)

  let resumed = reduce(stillPaused.runtime, .resume, at: clock.now, ids: &ids)
  let focus = expectFocus(resumed.runtime)
  #expect(focus.breakDueAt.timeIntervalSince(clock.now) == 1_000)
}

@Test
func boundedCatchUpAfterSleepOrRelaunchStartsOneBreak() {
  var ids = IdentifierFactory.deterministic()
  var clock = ManualClock()
  let runtime = boot(at: clock.now, ids: &ids).runtime
  let focus = expectFocus(runtime)

  // Sleep far past several theoretical cycles.
  clock.advance(by: 10_000)
  let caught = reduce(runtime, .reconcile, at: clock.now, ids: &ids)
  let breakPhase = expectBreak(caught.runtime)
  #expect(breakPhase.trigger == .catchUp)
  #expect(breakPhase.breakStartedAt == clock.now)
  #expect(breakPhase.breakEndsAt == clock.now.addingTimeInterval(20))
  #expect(breakPhase.cycleID == focus.cycleID)
  #expect(eventKinds(caught.events) == ["breakStarted(catchUp)"])
  #expect(caught.events[0].source == .recovery)

  // Completing that one break yields one fresh focus — no fabricated intermediates.
  clock.set(breakPhase.breakEndsAt)
  let after = reduce(caught.runtime, .reconcile, at: clock.now, ids: &ids)
  #expect(eventKinds(after.events) == ["breakCompleted", "sessionStarted"])
  #expect(expectFocus(after.runtime).focusStartedAt == breakPhase.breakEndsAt)
}

@Test
func overdueEndedBreakCompletesOnceThenAppliesBoundedCatchUp() {
  var ids = IdentifierFactory.deterministic()
  var clock = ManualClock()
  var runtime = boot(at: clock.now, ids: &ids).runtime
  clock.set(expectFocus(runtime).breakDueAt)
  runtime = reduce(runtime, .reconcile, at: clock.now, ids: &ids).runtime
  let breakPhase = expectBreak(runtime)

  // Resume long after break ended — past the next focus window too.
  clock.set(breakPhase.breakEndsAt.addingTimeInterval(5_000))
  let result = reduce(runtime, .reconcile, at: clock.now, ids: &ids)
  #expect(
    eventKinds(result.events) == [
      "breakCompleted",
      "sessionStarted",
      "breakStarted(catchUp)",
    ])
  let catchUp = expectBreak(result.runtime)
  #expect(catchUp.trigger == .catchUp)
  #expect(catchUp.breakStartedAt == clock.now)
}

@Test
func backwardClockJumpNeverCreatesReverseTransitions() {
  var ids = IdentifierFactory.deterministic()
  var clock = ManualClock()
  var runtime = boot(at: clock.now, ids: &ids).runtime
  clock.advance(by: 1_190)
  runtime = reduce(runtime, .reconcile, at: clock.now, ids: &ids).runtime
  let warningCycle = expectWarning(runtime).cycleID

  // Jump backward before warningStartsAt — remain in warning.
  clock.advance(by: -100)
  let stillWarning = reduce(runtime, .reconcile, at: clock.now, ids: &ids)
  #expect(expectWarning(stillWarning.runtime).cycleID == warningCycle)
  #expect(
    expectWarning(stillWarning.runtime).warningStartsAt == expectWarning(runtime).warningStartsAt)
  #expect(stillWarning.events.isEmpty)

  // Enter break, then jump backward — remain in break.
  clock.set(expectWarning(runtime).breakDueAt)
  runtime = reduce(runtime, .reconcile, at: clock.now, ids: &ids).runtime
  let breakPhase = expectBreak(runtime)
  clock.advance(by: -30)
  let stillBreak = reduce(runtime, .reconcile, at: clock.now, ids: &ids)
  #expect(expectBreak(stillBreak.runtime).breakEndsAt == breakPhase.breakEndsAt)
  #expect(stillBreak.events.isEmpty)
}

@Test
func reconcileIsIdempotentAtTheSameInstant() {
  var ids = IdentifierFactory.deterministic()
  var clock = ManualClock()
  let runtime = boot(at: clock.now, ids: &ids).runtime
  clock.advance(by: 1_195)
  let first = reduce(runtime, .reconcile, at: clock.now, ids: &ids)
  let second = reduce(first.runtime, .reconcile, at: clock.now, ids: &ids)
  #expect(second.runtime == first.runtime)
  #expect(second.events.isEmpty)
  #expect(first.presentation == .showWarning)

  clock.set(expectWarning(first.runtime).breakDueAt.addingTimeInterval(5))
  let catchUp = reduce(first.runtime, .reconcile, at: clock.now, ids: &ids)
  let again = reduce(catchUp.runtime, .reconcile, at: clock.now, ids: &ids)
  #expect(again.runtime == catchUp.runtime)
  #expect(again.events.isEmpty)
}

@Test
func staleWarningSnoozeCannotMutateAfterReconcileAdvancesToBreak() {
  var ids = IdentifierFactory.deterministic()
  var clock = ManualClock()
  var runtime = boot(at: clock.now, ids: &ids).runtime
  clock.advance(by: 1_190)
  runtime = reduce(runtime, .reconcile, at: clock.now, ids: &ids).runtime

  clock.set(expectWarning(runtime).breakDueAt.addingTimeInterval(1))
  let stale = reduce(runtime, .snooze(source: .warning), at: clock.now, ids: &ids)
  #expect(expectBreak(stale.runtime).trigger == .catchUp)
  #expect(stale.commandResult == .rejected(.invalidForPhase))
  #expect(eventKinds(stale.events) == ["breakStarted(catchUp)"])
}

@Test
func cliStartBootstrapsMissingRuntimeAndNoopsWhenActive() {
  var ids = IdentifierFactory.deterministic()
  let clock = ManualClock()

  let started = reduce(nil, .start, at: clock.now, ids: &ids)
  #expect(expectFocus(started.runtime).focusStartedAt == clock.now)
  #expect(started.commandResult == .performed)
  #expect(started.events[0].source == .cli)

  let noop = reduce(started.runtime, .start, at: clock.now, ids: &ids)
  #expect(noop.commandResult == .noop)
  #expect(noop.events.isEmpty)
}

@Test
func cliStartRejectsPausedRuntimeWithUseResume() {
  var ids = IdentifierFactory.deterministic()
  let clock = ManualClock()
  var runtime = boot(at: clock.now, ids: &ids).runtime
  runtime = reduce(runtime, .pause, at: clock.now, ids: &ids).runtime

  let rejected = reduce(runtime, .start, at: clock.now, ids: &ids)
  #expect(rejected.commandResult == .rejected(.useResume))
  #expect(expectPaused(rejected.runtime).pausedAt == clock.now)
}

@Test
func triggerBreakFromFocusWarningPausedAndNoopInBreak() {
  var ids = IdentifierFactory.deterministic()
  var clock = ManualClock()
  var runtime = boot(at: clock.now, ids: &ids).runtime

  let fromFocus = reduce(runtime, .triggerBreak, at: clock.now, ids: &ids)
  #expect(expectBreak(fromFocus.runtime).trigger == .cli)
  #expect(eventKinds(fromFocus.events) == ["breakStarted(cli)"])

  // Finish and return to focus, then warning path.
  clock.set(expectBreak(fromFocus.runtime).breakEndsAt)
  runtime = reduce(fromFocus.runtime, .reconcile, at: clock.now, ids: &ids).runtime
  clock.advance(by: 1_190)
  runtime = reduce(runtime, .reconcile, at: clock.now, ids: &ids).runtime
  let fromWarning = reduce(runtime, .triggerBreak, at: clock.now, ids: &ids)
  #expect(expectBreak(fromWarning.runtime).trigger == .cli)

  let noop = reduce(fromWarning.runtime, .triggerBreak, at: clock.now, ids: &ids)
  #expect(noop.commandResult == .noop)
  #expect(noop.events.isEmpty)

  // Pause during focus, then trigger-break abandons freeze and starts break.
  clock.set(expectBreak(fromWarning.runtime).breakEndsAt)
  runtime = reduce(fromWarning.runtime, .reconcile, at: clock.now, ids: &ids).runtime
  runtime = reduce(runtime, .pause, at: clock.now, ids: &ids).runtime
  clock.advance(by: 60)
  let fromPaused = reduce(runtime, .triggerBreak, at: clock.now, ids: &ids)
  let breakPhase = expectBreak(fromPaused.runtime)
  #expect(breakPhase.trigger == .cli)
  #expect(breakPhase.breakStartedAt == clock.now)
  #expect(breakPhase.breakEndsAt == clock.now.addingTimeInterval(20))
  #expect(fromPaused.presentation == .showBreakOverlay)
}

extension SessionPhase {
  fileprivate var pausedAtOrNil: Date? {
    guard case .paused(let paused) = self else { return nil }
    return paused.pausedAt
  }
}
