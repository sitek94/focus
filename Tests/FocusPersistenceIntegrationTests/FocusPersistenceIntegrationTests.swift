import CSQLite
import FocusPersistence
import FocusSession
import Foundation
import Testing

@Test
func moduleNameIsFocusPersistence() {
  #expect(FocusPersistenceModule.moduleName == "FocusPersistence")
}

@Test
func sqliteIsLinked() {
  #expect(FocusPersistenceModule.sqliteLinked)
}

@Test
func freshSchemaCreatesCanonicalTablesAtVersionOne() async throws {
  let store = try FocusEventStore(path: ":memory:")

  #expect(try await store.schemaVersion() == FocusSchema.currentVersion)
  #expect(try await store.userTableNames() == FocusSchema.tables.sorted())
  #expect(try await store.loadSnapshot() == nil)
  #expect(try await store.loadEvents().isEmpty)
}

@Test
func migrationFromVersionZeroAppliesV1Schema() async throws {
  let url = try temporaryDatabaseURL()
  try createLegacyVersionZeroDatabase(at: url)

  let store = try FocusEventStore(fileURL: url)
  #expect(try await store.schemaVersion() == 1)
  #expect(try await store.userTableNames() == FocusSchema.tables.sorted())

  // Migrated empty store still boots from a missing snapshot, not event replay.
  #expect(try await store.loadSnapshot() == nil)
  #expect(try await store.loadEvents().isEmpty)
}

@Test
func commitWritesSnapshotAndEventsAtomically() async throws {
  let store = try FocusEventStore(path: ":memory:")
  var ids = IdentifierFactory.deterministic()
  let now = Date(timeIntervalSince1970: 1_721_280_000)
  let reduction = SessionReducer.reduce(runtime: nil, intent: .start, at: now, ids: &ids)

  try await store.commit(snapshot: reduction.runtime, events: reduction.events)

  let loaded = try await store.loadSnapshot()
  #expect(loaded == reduction.runtime)
  #expect(try await store.loadEvents() == reduction.events)
  #expect(eventKindNames(try await store.loadEvents()) == ["sessionStarted"])
}

@Test
func failedCommitRollsBackSnapshotAndEvents() async throws {
  let store = try FocusEventStore(path: ":memory:")
  var ids = IdentifierFactory.deterministic()
  let now = Date(timeIntervalSince1970: 1_721_280_100)
  let first = SessionReducer.reduce(runtime: nil, intent: .start, at: now, ids: &ids)
  try await store.commit(snapshot: first.runtime, events: first.events)

  let warningAt = now.addingTimeInterval(FocusPolicy.focusUntilWarning)
  let warned = SessionReducer.reduce(
    runtime: first.runtime,
    intent: .reconcile,
    at: warningAt,
    ids: &ids
  )
  let snoozed = SessionReducer.reduce(
    runtime: warned.runtime,
    intent: .snooze(source: .warning),
    at: warningAt,
    ids: &ids
  )

  // Re-use an already-persisted sequence to force a constraint failure mid-transaction.
  let duplicate = OutcomeEvent(
    sequence: first.events[0].sequence,
    id: ids.next(),
    cycleID: first.events[0].cycleID,
    timestamp: now,
    source: .cli,
    kind: .breakSkipped
  )
  let conflictingRuntime = snoozed.runtime

  await #expect(throws: FocusPersistenceError.self) {
    try await store.commit(snapshot: conflictingRuntime, events: [duplicate])
  }

  #expect(try await store.loadSnapshot() == first.runtime)
  #expect(try await store.loadEvents() == first.events)
}

@Test
func pausedSnapshotRestoresWithoutAdvancing() async throws {
  let url = try temporaryDatabaseURL()
  var ids = IdentifierFactory.deterministic()
  let now = Date(timeIntervalSince1970: 1_721_280_200)
  var runtime = SessionReducer.reduce(runtime: nil, intent: .start, at: now, ids: &ids).runtime
  let pausedAt = now.addingTimeInterval(300)
  let paused = SessionReducer.reduce(runtime: runtime, intent: .pause, at: pausedAt, ids: &ids)
  runtime = paused.runtime

  do {
    let store = try FocusEventStore(fileURL: url)
    try await store.commit(snapshot: runtime, events: paused.events)
  }

  let restored = try FocusEventStore(fileURL: url)
  let snapshot = try #require(try await restored.loadSnapshot())
  guard case .paused(let phase) = snapshot.phase else {
    Issue.record("Expected paused snapshot, got \(snapshot.phase)")
    return
  }
  #expect(phase.pausedAt == pausedAt)
  guard case .focus(let untilWarning, let untilBreak) = phase.remaining else {
    Issue.record("Expected focus remainders, got \(phase.remaining)")
    return
  }
  #expect(untilWarning == FocusPolicy.focusUntilWarning - 300)
  #expect(untilBreak == FocusPolicy.focusDuration - 300)
}

@Test
func persistsRequiredStartedCompletedSnoozedSkippedRecords() async throws {
  let store = try FocusEventStore(path: ":memory:")
  var ids = IdentifierFactory.deterministic()
  let start = Date(timeIntervalSince1970: 1_721_280_300)
  var runtime: SessionRuntime?
  var allEvents: [OutcomeEvent] = []

  func apply(_ intent: SessionIntent, at now: Date) {
    let result = SessionReducer.reduce(runtime: runtime, intent: intent, at: now, ids: &ids)
    runtime = result.runtime
    allEvents.append(contentsOf: result.events)
  }

  apply(.start, at: start)
  let warningAt = start.addingTimeInterval(FocusPolicy.focusUntilWarning)
  apply(.reconcile, at: warningAt)
  apply(.snooze(source: .warning), at: warningAt)

  let secondWarning = warningAt.addingTimeInterval(FocusPolicy.snoozeDuration)
  apply(.reconcile, at: secondWarning.addingTimeInterval(-FocusPolicy.warningDuration))
  apply(.reconcile, at: secondWarning)
  // break started at due; complete it
  let breakEnds = secondWarning.addingTimeInterval(FocusPolicy.breakDuration)
  apply(.reconcile, at: breakEnds)

  let nextWarning = breakEnds.addingTimeInterval(FocusPolicy.focusUntilWarning)
  apply(.reconcile, at: nextWarning)
  apply(.skip(source: .cli), at: nextWarning)

  let snapshot = try #require(runtime)
  try await store.commit(snapshot: snapshot, events: allEvents)

  let loaded = try await store.loadEvents()
  let kinds = Set(eventKindNames(loaded))
  #expect(kinds.contains("sessionStarted"))
  #expect(kinds.contains("breakCompleted"))
  #expect(kinds.contains("breakSnoozed"))
  #expect(kinds.contains("breakSkipped"))
  #expect(kinds.contains("breakStarted"))
}

@Test
func eventSequenceOrderingIsStableOnRead() async throws {
  let store = try FocusEventStore(path: ":memory:")
  let cycleID = UUID(uuidString: "00000000-0000-4000-8000-0000000000AA")!
  let base = Date(timeIntervalSince1970: 1_721_280_400)
  let events = [
    OutcomeEvent(
      sequence: 3,
      id: UUID(uuidString: "00000000-0000-4000-8000-000000000003")!,
      cycleID: cycleID,
      timestamp: base.addingTimeInterval(2),
      source: .timer,
      kind: .breakCompleted
    ),
    OutcomeEvent(
      sequence: 1,
      id: UUID(uuidString: "00000000-0000-4000-8000-000000000001")!,
      cycleID: cycleID,
      timestamp: base,
      source: .timer,
      kind: .sessionStarted
    ),
    OutcomeEvent(
      sequence: 2,
      id: UUID(uuidString: "00000000-0000-4000-8000-000000000002")!,
      cycleID: cycleID,
      timestamp: base.addingTimeInterval(1),
      source: .timer,
      kind: .breakStarted(trigger: .scheduled)
    ),
  ]

  let runtime = SessionRuntime(
    phase: .focus(
      FocusPhase(
        cycleID: cycleID,
        focusStartedAt: base,
        warningStartsAt: base.addingTimeInterval(FocusPolicy.focusUntilWarning),
        breakDueAt: base.addingTimeInterval(FocusPolicy.focusDuration)
      )
    ),
    lastSequence: 3
  )

  // Commit one-by-one in descending sequence order; reads must still ascend.
  try await store.commit(snapshot: runtime, events: [events[0]])
  try await store.commit(snapshot: runtime, events: [events[1]])
  try await store.commit(snapshot: runtime, events: [events[2]])

  let loaded = try await store.loadEvents()
  #expect(loaded.map(\.sequence) == [1, 2, 3])
  #expect(eventKindNames(loaded) == ["sessionStarted", "breakStarted", "breakCompleted"])
}

@Test
func corruptSnapshotFailsClearly() async throws {
  let url = try temporaryDatabaseURL()
  do {
    let store = try FocusEventStore(fileURL: url)
    var ids = IdentifierFactory.deterministic()
    let now = Date(timeIntervalSince1970: 1_721_280_500)
    let boot = SessionReducer.reduce(runtime: nil, intent: .start, at: now, ids: &ids)
    try await store.commit(snapshot: boot.runtime, events: boot.events)
  }

  try corruptRuntimeSnapshotJSON(at: url, payload: #"{"not":"a-session-runtime"}"#)

  let store = try FocusEventStore(fileURL: url)
  await #expect(throws: FocusPersistenceError.self) {
    _ = try await store.loadSnapshot()
  }

  do {
    _ = try await store.loadSnapshot()
    Issue.record("Expected corrupt snapshot to throw")
  } catch let error as FocusPersistenceError {
    guard case .corruptSnapshot(let message) = error else {
      Issue.record("Expected corruptSnapshot, got \(error)")
      return
    }
    #expect(!message.isEmpty)
  } catch {
    Issue.record("Unexpected error type: \(error)")
  }
}

@Test
func schemaHasNoTimingPreferenceFields() async throws {
  let store = try FocusEventStore(path: ":memory:")
  let columns = try await store.allColumnNames().map { $0.lowercased() }
  let tables = try await store.userTableNames().map { $0.lowercased() }

  let bannedSubstrings = [
    "focus_duration",
    "warning_duration",
    "break_duration",
    "snooze_duration",
    "preference",
    "preferences",
    "timing",
    "interval_seconds",
    "config_duration",
  ]

  for banned in bannedSubstrings {
    #expect(!columns.contains(where: { $0.contains(banned) }))
    #expect(!tables.contains(where: { $0.contains(banned) }))
  }

  #expect(tables.sorted() == FocusSchema.tables.sorted())
}

// MARK: - Helpers

private func temporaryDatabaseURL() throws -> URL {
  let directory = FileManager.default.temporaryDirectory
    .appendingPathComponent("focus-persistence-tests", isDirectory: true)
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  return directory.appendingPathComponent("\(UUID().uuidString).sqlite")
}

/// Pre-v1 fixture: `schema_meta` only, version 0, no snapshot/event tables.
private func createLegacyVersionZeroDatabase(at url: URL) throws {
  var db: OpaquePointer?
  let openResult = url.path.withCString { path in
    sqlite3_open_v2(path, &db, SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE, nil)
  }
  guard openResult == SQLITE_OK, let db else {
    throw FocusPersistenceError.sqlite(code: openResult, message: "failed to create fixture")
  }
  defer { sqlite3_close(db) }

  try exec(
    db,
    """
    CREATE TABLE schema_meta (
      key TEXT PRIMARY KEY NOT NULL,
      value TEXT NOT NULL
    );
    INSERT INTO schema_meta (key, value) VALUES ('schema_version', '0');
    """
  )
}

private func corruptRuntimeSnapshotJSON(at url: URL, payload: String) throws {
  var db: OpaquePointer?
  let openResult = url.path.withCString { path in
    sqlite3_open_v2(path, &db, SQLITE_OPEN_READWRITE, nil)
  }
  guard openResult == SQLITE_OK, let db else {
    throw FocusPersistenceError.sqlite(code: openResult, message: "failed to open fixture")
  }
  defer { sqlite3_close(db) }

  var statement: OpaquePointer?
  let sql = "UPDATE runtime_snapshot SET snapshot_json = ? WHERE singleton = 1;"
  guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
    throw FocusPersistenceError.sqlite(
      code: sqlite3_errcode(db),
      message: String(cString: sqlite3_errmsg(db))
    )
  }
  defer { sqlite3_finalize(statement) }

  let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
  _ = payload.withCString { cString in
    sqlite3_bind_text(statement, 1, cString, -1, transient)
  }
  guard sqlite3_step(statement) == SQLITE_DONE else {
    throw FocusPersistenceError.sqlite(
      code: sqlite3_errcode(db),
      message: String(cString: sqlite3_errmsg(db))
    )
  }
}

private func exec(_ db: OpaquePointer, _ sql: String) throws {
  var errorMessage: UnsafeMutablePointer<CChar>?
  let result = sql.withCString { cSQL in
    sqlite3_exec(db, cSQL, nil, nil, &errorMessage)
  }
  if result != SQLITE_OK {
    let message = errorMessage.map { String(cString: $0) } ?? "sqlite3_exec failed"
    if let errorMessage {
      sqlite3_free(errorMessage)
    }
    throw FocusPersistenceError.sqlite(code: result, message: message)
  }
}

private func eventKindNames(_ events: [OutcomeEvent]) -> [String] {
  events.map { event in
    switch event.kind {
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
