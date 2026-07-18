import FocusSession
import Foundation
import Testing

@discardableResult
func reduce(
  _ runtime: SessionRuntime?,
  _ intent: SessionIntent,
  at now: Date,
  ids: inout IdentifierFactory
) -> SessionReduction {
  SessionReducer.reduce(runtime: runtime, intent: intent, at: now, ids: &ids)
}

func boot(at now: Date, ids: inout IdentifierFactory) -> SessionReduction {
  reduce(nil, .reconcile, at: now, ids: &ids)
}

func expectFocus(_ runtime: SessionRuntime) -> FocusPhase {
  guard case .focus(let phase) = runtime.phase else {
    Issue.record("Expected focus phase, got \(runtime.phase)")
    return FocusPhase(
      cycleID: UUID(),
      focusStartedAt: .distantPast,
      warningStartsAt: .distantPast,
      breakDueAt: .distantPast
    )
  }
  return phase
}

func expectWarning(_ runtime: SessionRuntime) -> WarningPhase {
  guard case .warning(let phase) = runtime.phase else {
    Issue.record("Expected warning phase, got \(runtime.phase)")
    return WarningPhase(
      cycleID: UUID(),
      focusStartedAt: .distantPast,
      warningStartsAt: .distantPast,
      breakDueAt: .distantPast,
      warningStartedAt: .distantPast
    )
  }
  return phase
}

func expectBreak(_ runtime: SessionRuntime) -> BreakPhase {
  guard case .breakTime(let phase) = runtime.phase else {
    Issue.record("Expected break phase, got \(runtime.phase)")
    return BreakPhase(
      cycleID: UUID(),
      breakStartedAt: .distantPast,
      breakEndsAt: .distantPast,
      trigger: .scheduled
    )
  }
  return phase
}

func expectPaused(_ runtime: SessionRuntime) -> PausedPhase {
  guard case .paused(let phase) = runtime.phase else {
    Issue.record("Expected paused phase, got \(runtime.phase)")
    return PausedPhase(
      frozen: .focus(
        FocusPhase(
          cycleID: UUID(),
          focusStartedAt: .distantPast,
          warningStartsAt: .distantPast,
          breakDueAt: .distantPast
        )
      ),
      pausedAt: .distantPast,
      remaining: .focus(untilWarning: 0, untilBreak: 0)
    )
  }
  return phase
}

func eventKinds(_ events: [OutcomeEvent]) -> [String] {
  events.map { event in
    switch event.kind {
    case .sessionStarted:
      return "sessionStarted"
    case .breakStarted(let trigger):
      return "breakStarted(\(trigger.rawValue))"
    case .breakCompleted:
      return "breakCompleted"
    case .breakSnoozed:
      return "breakSnoozed"
    case .breakSkipped:
      return "breakSkipped"
    }
  }
}
