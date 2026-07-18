import FocusSession
import Foundation

/// Maps `SessionRuntime` into the stable CLI JSON state projection.
public enum ControlStateProjector: Sendable {
  public static func project(runtime: SessionRuntime, at now: Date) -> ControlSessionState {
    switch runtime.phase {
    case .focus(let focus):
      let seconds = max(0, Int(focus.warningStartsAt.timeIntervalSince(now).rounded(.down)))
      return ControlSessionState(
        phase: "focus",
        cycleId: focus.cycleID,
        focusStartedAt: focus.focusStartedAt,
        warningStartsAt: focus.warningStartsAt,
        breakDueAt: focus.breakDueAt,
        breakEndsAt: nil,
        secondsUntilNextTransition: seconds,
        canPause: true,
        canResume: false,
        canSkip: false,
        canTriggerBreak: true,
        canSnooze: false
      )

    case .warning(let warning):
      let seconds = max(0, Int(warning.breakDueAt.timeIntervalSince(now).rounded(.down)))
      return ControlSessionState(
        phase: "warning",
        cycleId: warning.cycleID,
        focusStartedAt: warning.focusStartedAt,
        warningStartsAt: warning.warningStartsAt,
        breakDueAt: warning.breakDueAt,
        breakEndsAt: nil,
        secondsUntilNextTransition: seconds,
        canPause: true,
        canResume: false,
        canSkip: true,
        canTriggerBreak: true,
        canSnooze: true
      )

    case .breakTime(let breakPhase):
      let seconds = max(0, Int(breakPhase.breakEndsAt.timeIntervalSince(now).rounded(.down)))
      return ControlSessionState(
        phase: "break",
        cycleId: breakPhase.cycleID,
        focusStartedAt: nil,
        warningStartsAt: nil,
        breakDueAt: nil,
        breakEndsAt: breakPhase.breakEndsAt,
        secondsUntilNextTransition: seconds,
        canPause: true,
        canResume: false,
        canSkip: true,
        canTriggerBreak: false,
        canSnooze: false
      )

    case .paused(let paused):
      return projectPaused(paused)
    }
  }

  private static func projectPaused(_ paused: PausedPhase) -> ControlSessionState {
    let cycleId: UUID
    let focusStartedAt: Date?
    let warningStartsAt: Date?
    let breakDueAt: Date?
    let breakEndsAt: Date?
    let seconds: Int
    let frozenPhaseName: String

    switch paused.frozen {
    case .focus(let focus):
      cycleId = focus.cycleID
      focusStartedAt = focus.focusStartedAt
      warningStartsAt = focus.warningStartsAt
      breakDueAt = focus.breakDueAt
      breakEndsAt = nil
      frozenPhaseName = "paused"
      if case .focus(let untilWarning, _) = paused.remaining {
        seconds = max(0, Int(untilWarning.rounded(.down)))
      } else {
        seconds = 0
      }

    case .warning(let warning):
      cycleId = warning.cycleID
      focusStartedAt = warning.focusStartedAt
      warningStartsAt = warning.warningStartsAt
      breakDueAt = warning.breakDueAt
      breakEndsAt = nil
      frozenPhaseName = "paused"
      if case .warning(let untilBreak) = paused.remaining {
        seconds = max(0, Int(untilBreak.rounded(.down)))
      } else {
        seconds = 0
      }

    case .breakTime(let breakPhase):
      cycleId = breakPhase.cycleID
      focusStartedAt = nil
      warningStartsAt = nil
      breakDueAt = nil
      breakEndsAt = breakPhase.breakEndsAt
      frozenPhaseName = "paused"
      if case .breakTime(let untilEnd) = paused.remaining {
        seconds = max(0, Int(untilEnd.rounded(.down)))
      } else {
        seconds = 0
      }
    }

    return ControlSessionState(
      phase: frozenPhaseName,
      cycleId: cycleId,
      focusStartedAt: focusStartedAt,
      warningStartsAt: warningStartsAt,
      breakDueAt: breakDueAt,
      breakEndsAt: breakEndsAt,
      secondsUntilNextTransition: seconds,
      canPause: false,
      canResume: true,
      canSkip: false,
      canTriggerBreak: true,
      canSnooze: false
    )
  }
}
