import Foundation

/// User, CLI, or scheduler intent applied after reconciliation.
public enum SessionIntent: Sendable, Equatable, Codable {
  /// Advance the runtime to `now` without a user command.
  case reconcile
  /// Warning UI “Start now” — begin a full break immediately.
  case startNow
  /// Warning / CLI snooze — postpone break due by 60 seconds.
  case snooze(source: OutcomeEventSource)
  /// Skip the current warning or break obligation.
  case skip(source: OutcomeEventSource)
  /// Freeze remaining durations; paused time never counts.
  case pause
  /// Rebuild deadlines from frozen remainders.
  case resume
  /// CLI `start` — bootstrap missing runtime; no-op if already active.
  case start
  /// CLI `trigger-break` — begin a full break from focus/warning/paused.
  case triggerBreak
}

/// Result of applying a command after reconciliation.
public enum SessionCommandResult: Sendable, Equatable, Codable {
  case performed
  case noop
  case rejected(SessionRejection)
}

/// Why a command could not be applied to the reconciled runtime.
public enum SessionRejection: String, Sendable, Equatable, Codable {
  /// CLI `start` against a paused runtime — caller must `resume`.
  case useResume
  /// Command is not valid for the current phase.
  case invalidForPhase
}

/// Presentation guidance derived from the post-reduction phase.
public enum PresentationDirective: String, Sendable, Equatable, Codable {
  case none
  case showWarning
  case showBreakOverlay
  case hideWhilePaused
}

/// Pure reduction output.
public struct SessionReduction: Sendable, Equatable {
  public var runtime: SessionRuntime
  public var events: [OutcomeEvent]
  public var presentation: PresentationDirective
  public var commandResult: SessionCommandResult

  public init(
    runtime: SessionRuntime,
    events: [OutcomeEvent],
    presentation: PresentationDirective,
    commandResult: SessionCommandResult
  ) {
    self.runtime = runtime
    self.events = events
    self.presentation = presentation
    self.commandResult = commandResult
  }
}
