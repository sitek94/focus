import Foundation

/// Canonical Focus SQLite schema identifiers and migration surface.
public enum FocusSchema: Sendable {
  /// Latest schema version applied by ``SchemaMigrator``.
  public static let currentVersion = 1

  public static let schemaMetaTable = "schema_meta"
  public static let runtimeSnapshotTable = "runtime_snapshot"
  public static let outcomeEventsTable = "outcome_events"

  public static let schemaVersionKey = "schema_version"

  /// Tables owned by FocusPersistence. No stats/analytics/preference tables.
  public static let tables: [String] = [
    schemaMetaTable,
    runtimeSnapshotTable,
    outcomeEventsTable,
  ]
}

/// Applies versioned schema migrations against an open SQLite connection.
enum SchemaMigrator {
  static func migrate(_ connection: SQLiteConnection) throws {
    try connection.execute("PRAGMA foreign_keys = ON;")
    try ensureSchemaMeta(connection)

    var version = try readSchemaVersion(connection)
    if version > FocusSchema.currentVersion {
      throw FocusPersistenceError.schema(
        "Database schema version \(version) is newer than supported \(FocusSchema.currentVersion)."
      )
    }

    while version < FocusSchema.currentVersion {
      let next = version + 1
      try applyMigration(from: version, to: next, on: connection)
      try writeSchemaVersion(next, on: connection)
      version = next
    }
  }

  /// Migration hook path: each step is explicit so future versions can append.
  static func applyMigration(from: Int, to: Int, on connection: SQLiteConnection) throws {
    switch (from, to) {
    case (0, 1):
      try migrateV0ToV1(connection)
    default:
      throw FocusPersistenceError.schema("No migration registered from \(from) to \(to).")
    }
  }

  private static func migrateV0ToV1(_ connection: SQLiteConnection) throws {
    try connection.execute(
      """
      CREATE TABLE IF NOT EXISTS \(FocusSchema.runtimeSnapshotTable) (
        singleton INTEGER PRIMARY KEY NOT NULL CHECK (singleton = 1),
        snapshot_json TEXT NOT NULL,
        updated_at_utc REAL NOT NULL
      );
      """
    )
    try connection.execute(
      """
      CREATE TABLE IF NOT EXISTS \(FocusSchema.outcomeEventsTable) (
        sequence INTEGER PRIMARY KEY NOT NULL,
        event_id TEXT NOT NULL UNIQUE,
        cycle_id TEXT NOT NULL,
        schema_version INTEGER NOT NULL,
        timestamp_utc REAL NOT NULL,
        source TEXT NOT NULL,
        kind TEXT NOT NULL,
        event_json TEXT NOT NULL
      );
      """
    )
  }

  private static func ensureSchemaMeta(_ connection: SQLiteConnection) throws {
    try connection.execute(
      """
      CREATE TABLE IF NOT EXISTS \(FocusSchema.schemaMetaTable) (
        key TEXT PRIMARY KEY NOT NULL,
        value TEXT NOT NULL
      );
      """
    )
  }

  static func readSchemaVersion(_ connection: SQLiteConnection) throws -> Int {
    let sql = """
      SELECT value FROM \(FocusSchema.schemaMetaTable)
      WHERE key = ? LIMIT 1;
      """
    return try connection.prepare(sql) { statement in
      try statement.bind(FocusSchema.schemaVersionKey, at: 1)
      guard try statement.step() else {
        return 0
      }
      guard let raw = statement.text(at: 0), let version = Int(raw) else {
        throw FocusPersistenceError.schema(
          "schema_meta.schema_version is missing or not an integer.")
      }
      return version
    }
  }

  private static func writeSchemaVersion(_ version: Int, on connection: SQLiteConnection) throws {
    let sql = """
      INSERT INTO \(FocusSchema.schemaMetaTable) (key, value) VALUES (?, ?)
      ON CONFLICT(key) DO UPDATE SET value = excluded.value;
      """
    try connection.prepare(sql) { statement in
      try statement.bind(FocusSchema.schemaVersionKey, at: 1)
      try statement.bind(String(version), at: 2)
      _ = try statement.step()
    }
  }
}
