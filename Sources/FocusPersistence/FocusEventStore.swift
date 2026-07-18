import FocusSession
import Foundation

/// Actor-isolated SQLite store for the runtime snapshot and append-only outcome log.
///
/// Runtime restore always reads ``runtime_snapshot``; events are never replayed.
public actor FocusEventStore {
  private let connection: SQLiteConnection

  /// Opens or creates a database file and migrates it to ``FocusSchema/currentVersion``.
  public init(fileURL: URL) throws {
    let connection = try SQLiteConnection(fileURL: fileURL)
    try SchemaMigrator.migrate(connection)
    self.connection = connection
  }

  /// Convenience for path-based call sites and tests (`:memory:` supported).
  public init(path: String) throws {
    let connection = try SQLiteConnection(path: path)
    try SchemaMigrator.migrate(connection)
    self.connection = connection
  }

  /// Current applied schema version from `schema_meta`.
  public func schemaVersion() throws -> Int {
    try SchemaMigrator.readSchemaVersion(connection)
  }

  /// Loads the persisted runtime snapshot, if any.
  ///
  /// - Returns: `nil` when no snapshot row exists (first launch).
  /// - Throws: ``FocusPersistenceError/corruptSnapshot`` when the payload cannot be decoded.
  public func loadSnapshot() throws -> SessionRuntime? {
    let sql = """
      SELECT snapshot_json FROM \(FocusSchema.runtimeSnapshotTable)
      WHERE singleton = 1 LIMIT 1;
      """
    return try connection.prepare(sql) { statement in
      guard try statement.step() else {
        return nil
      }
      guard let json = statement.text(at: 0) else {
        throw FocusPersistenceError.corruptSnapshot("runtime_snapshot.snapshot_json is NULL.")
      }
      return try PersistenceCodec.decodeSnapshot(json)
    }
  }

  /// Loads append-only outcome events ordered by ascending sequence.
  public func loadEvents(after sequence: UInt64 = 0) throws -> [OutcomeEvent] {
    let sql = """
      SELECT event_json FROM \(FocusSchema.outcomeEventsTable)
      WHERE sequence > ?
      ORDER BY sequence ASC;
      """
    return try connection.prepare(sql) { statement in
      try statement.bind(sequence, at: 1)
      var events: [OutcomeEvent] = []
      while try statement.step() {
        guard let json = statement.text(at: 0) else {
          throw FocusPersistenceError.corruptSnapshot("outcome_events.event_json is NULL.")
        }
        events.append(try PersistenceCodec.decodeEvent(json))
      }
      return events
    }
  }

  /// Writes a new runtime snapshot and appends events in a single transaction.
  ///
  /// On any failure the transaction is rolled back and neither snapshot nor events change.
  public func commit(snapshot: SessionRuntime, events: [OutcomeEvent]) throws {
    let snapshotJSON = try PersistenceCodec.encodeSnapshot(snapshot)
    let encodedEvents = try events.map { event -> EncodedEvent in
      EncodedEvent(
        sequence: event.sequence,
        eventID: event.id.uuidString,
        cycleID: event.cycleID.uuidString,
        schemaVersion: event.schemaVersion,
        timestampUTC: event.timestamp.timeIntervalSince1970,
        source: event.source.rawValue,
        kind: kindDiscriminant(event.kind),
        eventJSON: try PersistenceCodec.encodeEvent(event)
      )
    }

    try connection.beginImmediateTransaction()
    do {
      try upsertSnapshot(json: snapshotJSON, updatedAt: Date().timeIntervalSince1970)
      for event in encodedEvents {
        try insertEvent(event)
      }
      try connection.commitTransaction()
    } catch {
      try? connection.rollbackTransaction()
      if let persistenceError = error as? FocusPersistenceError {
        throw persistenceError
      }
      throw FocusPersistenceError.commitFailed(String(describing: error))
    }
  }

  /// Column names across all Focus tables (for schema assertions in tests).
  public func allColumnNames() throws -> [String] {
    var names: [String] = []
    for table in FocusSchema.tables {
      let sql = "PRAGMA table_info(\(table));"
      try connection.prepare(sql) { statement in
        while try statement.step() {
          if let name = statement.text(at: 1) {
            names.append(name)
          }
        }
      }
    }
    return names
  }

  /// User table names present in the database.
  public func userTableNames() throws -> [String] {
    let sql = """
      SELECT name FROM sqlite_master
      WHERE type = 'table' AND name NOT LIKE 'sqlite_%'
      ORDER BY name ASC;
      """
    return try connection.prepare(sql) { statement in
      var tables: [String] = []
      while try statement.step() {
        if let name = statement.text(at: 0) {
          tables.append(name)
        }
      }
      return tables
    }
  }

  private func upsertSnapshot(json: String, updatedAt: Double) throws {
    let sql = """
      INSERT INTO \(FocusSchema.runtimeSnapshotTable) (singleton, snapshot_json, updated_at_utc)
      VALUES (1, ?, ?)
      ON CONFLICT(singleton) DO UPDATE SET
        snapshot_json = excluded.snapshot_json,
        updated_at_utc = excluded.updated_at_utc;
      """
    try connection.prepare(sql) { statement in
      try statement.bind(json, at: 1)
      try statement.bind(updatedAt, at: 2)
      _ = try statement.step()
    }
  }

  private func insertEvent(_ event: EncodedEvent) throws {
    let sql = """
      INSERT INTO \(FocusSchema.outcomeEventsTable) (
        sequence, event_id, cycle_id, schema_version,
        timestamp_utc, source, kind, event_json
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?);
      """
    try connection.prepare(sql) { statement in
      try statement.bind(event.sequence, at: 1)
      try statement.bind(event.eventID, at: 2)
      try statement.bind(event.cycleID, at: 3)
      try statement.bind(event.schemaVersion, at: 4)
      try statement.bind(event.timestampUTC, at: 5)
      try statement.bind(event.source, at: 6)
      try statement.bind(event.kind, at: 7)
      try statement.bind(event.eventJSON, at: 8)
      _ = try statement.step()
    }
  }

  private func kindDiscriminant(_ kind: OutcomeEventKind) -> String {
    switch kind {
    case .sessionStarted:
      return "sessionStarted"
    case .breakStarted:
      return "breakStarted"
    case .breakCompleted:
      return "breakCompleted"
    case .breakSnoozed:
      return "breakSnoozed"
    case .breakSkipped:
      return "breakSkipped"
    }
  }
}

private struct EncodedEvent {
  var sequence: UInt64
  var eventID: String
  var cycleID: String
  var schemaVersion: Int
  var timestampUTC: Double
  var source: String
  var kind: String
  var eventJSON: String
}
