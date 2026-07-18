import Foundation

/// Provenance for a minimal behavioral outcome event.
public enum OutcomeEventSource: String, Sendable, Equatable, Codable, CaseIterable {
  case timer
  case warning
  case cli
  case recovery
}

/// Discriminated payload for a persisted outcome event.
public enum OutcomeEventKind: Sendable, Equatable, Codable {
  case sessionStarted
  case breakStarted(trigger: BreakTrigger)
  case breakCompleted
  case breakSnoozed(deadline: Date)
  case breakSkipped
}

/// Append-only behavioral outcome emitted by the session reducer.
public struct OutcomeEvent: Sendable, Equatable, Identifiable, Codable {
  public var schemaVersion: Int
  public var sequence: UInt64
  public var id: UUID
  public var cycleID: UUID
  public var timestamp: Date
  public var source: OutcomeEventSource
  public var kind: OutcomeEventKind

  public init(
    schemaVersion: Int = FocusPolicy.outcomeSchemaVersion,
    sequence: UInt64,
    id: UUID,
    cycleID: UUID,
    timestamp: Date,
    source: OutcomeEventSource,
    kind: OutcomeEventKind
  ) {
    self.schemaVersion = schemaVersion
    self.sequence = sequence
    self.id = id
    self.cycleID = cycleID
    self.timestamp = timestamp
    self.source = source
    self.kind = kind
  }
}
