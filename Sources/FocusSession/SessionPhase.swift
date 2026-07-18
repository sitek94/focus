import Foundation

/// Why a break began.
public enum BreakTrigger: String, Sendable, Equatable, Codable, CaseIterable {
  case scheduled
  case startNow
  case cli
  case catchUp
}

/// Active focus interval waiting for warning/break deadlines.
public struct FocusPhase: Sendable, Equatable, Codable {
  public var cycleID: UUID
  public var focusStartedAt: Date
  public var warningStartsAt: Date
  public var breakDueAt: Date

  public init(
    cycleID: UUID,
    focusStartedAt: Date,
    warningStartsAt: Date,
    breakDueAt: Date
  ) {
    self.cycleID = cycleID
    self.focusStartedAt = focusStartedAt
    self.warningStartsAt = warningStartsAt
    self.breakDueAt = breakDueAt
  }
}

/// Warning window in the final seconds before a break is due.
public struct WarningPhase: Sendable, Equatable, Codable {
  public var cycleID: UUID
  public var focusStartedAt: Date
  public var warningStartsAt: Date
  public var breakDueAt: Date
  public var warningStartedAt: Date

  public init(
    cycleID: UUID,
    focusStartedAt: Date,
    warningStartsAt: Date,
    breakDueAt: Date,
    warningStartedAt: Date
  ) {
    self.cycleID = cycleID
    self.focusStartedAt = focusStartedAt
    self.warningStartsAt = warningStartsAt
    self.breakDueAt = breakDueAt
    self.warningStartedAt = warningStartedAt
  }
}

/// Active break overlay interval.
public struct BreakPhase: Sendable, Equatable, Codable {
  public var cycleID: UUID
  public var breakStartedAt: Date
  public var breakEndsAt: Date
  public var trigger: BreakTrigger

  public init(
    cycleID: UUID,
    breakStartedAt: Date,
    breakEndsAt: Date,
    trigger: BreakTrigger
  ) {
    self.cycleID = cycleID
    self.breakStartedAt = breakStartedAt
    self.breakEndsAt = breakEndsAt
    self.trigger = trigger
  }
}

/// Phase that can be frozen by pause (never nested pause).
public enum FreezeablePhase: Sendable, Equatable, Codable {
  case focus(FocusPhase)
  case warning(WarningPhase)
  case breakTime(BreakPhase)
}

/// Exact remaining durations captured at pause time.
public enum PausedRemaining: Sendable, Equatable, Codable {
  case focus(untilWarning: TimeInterval, untilBreak: TimeInterval)
  case warning(untilBreak: TimeInterval)
  case breakTime(untilEnd: TimeInterval)
}

/// Paused runtime: prior phase, pause instant, and frozen remainders.
public struct PausedPhase: Sendable, Equatable, Codable {
  public var frozen: FreezeablePhase
  public var pausedAt: Date
  public var remaining: PausedRemaining

  public init(frozen: FreezeablePhase, pausedAt: Date, remaining: PausedRemaining) {
    self.frozen = frozen
    self.pausedAt = pausedAt
    self.remaining = remaining
  }
}

/// Runtime phase of a focus session.
public enum SessionPhase: Sendable, Equatable, Codable {
  case focus(FocusPhase)
  case warning(WarningPhase)
  case breakTime(BreakPhase)
  case paused(PausedPhase)

  public var cycleID: UUID {
    switch self {
    case .focus(let phase):
      return phase.cycleID
    case .warning(let phase):
      return phase.cycleID
    case .breakTime(let phase):
      return phase.cycleID
    case .paused(let phase):
      switch phase.frozen {
      case .focus(let frozen):
        return frozen.cycleID
      case .warning(let frozen):
        return frozen.cycleID
      case .breakTime(let frozen):
        return frozen.cycleID
      }
    }
  }

  /// Next absolute wall-clock deadline that should wake the runtime, if any.
  public var nextDeadline: Date? {
    switch self {
    case .focus(let phase):
      return phase.warningStartsAt
    case .warning(let phase):
      return phase.breakDueAt
    case .breakTime(let phase):
      return phase.breakEndsAt
    case .paused:
      return nil
    }
  }
}

/// Persisted/runtime envelope around the active phase.
public struct SessionRuntime: Sendable, Equatable, Codable {
  public var phase: SessionPhase
  /// Highest outcome-event sequence emitted for this runtime.
  public var lastSequence: UInt64

  public init(phase: SessionPhase, lastSequence: UInt64 = 0) {
    self.phase = phase
    self.lastSequence = lastSequence
  }
}
