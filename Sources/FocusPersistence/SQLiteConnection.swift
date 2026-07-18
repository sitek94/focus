import CSQLite
import Foundation

/// Actor-owned SQLite handle. Not shared across isolation domains.
final class SQLiteConnection {
  private var db: OpaquePointer?

  convenience init(fileURL: URL) throws {
    try self.init(path: Self.sqlitePath(from: fileURL))
  }

  init(path: String) throws {
    var handle: OpaquePointer?
    let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
    let openResult = path.withCString { cPath in
      sqlite3_open_v2(cPath, &handle, flags, nil)
    }
    guard openResult == SQLITE_OK, let handle else {
      let message = handle.map { String(cString: sqlite3_errmsg($0)) } ?? "sqlite3_open_v2 failed"
      if let handle {
        sqlite3_close(handle)
      }
      throw FocusPersistenceError.sqlite(code: openResult, message: message)
    }
    self.db = handle
    sqlite3_busy_timeout(handle, 5_000)
  }

  deinit {
    if let db {
      sqlite3_close(db)
    }
  }

  var handle: OpaquePointer {
    get throws {
      guard let db else {
        throw FocusPersistenceError.sqlite(code: SQLITE_MISUSE, message: "Database is closed.")
      }
      return db
    }
  }

  func execute(_ sql: String) throws {
    let db = try handle
    var errorMessage: UnsafeMutablePointer<CChar>?
    let result = sql.withCString { cSQL in
      sqlite3_exec(db, cSQL, nil, nil, &errorMessage)
    }
    if result != SQLITE_OK {
      let message: String
      if let errorMessage {
        message = String(cString: errorMessage)
        sqlite3_free(errorMessage)
      } else {
        message = String(cString: sqlite3_errmsg(db))
      }
      throw FocusPersistenceError.sqlite(code: result, message: message)
    }
  }

  func prepare<T>(_ sql: String, body: (SQLiteStatement) throws -> T) throws -> T {
    let db = try handle
    var statementHandle: OpaquePointer?
    let prepareResult = sql.withCString { cSQL in
      sqlite3_prepare_v2(db, cSQL, -1, &statementHandle, nil)
    }
    guard prepareResult == SQLITE_OK, let statementHandle else {
      throw FocusPersistenceError.sqlite(
        code: prepareResult,
        message: String(cString: sqlite3_errmsg(db))
      )
    }
    let statement = SQLiteStatement(handle: statementHandle, database: db)
    defer { statement.finalize() }
    return try body(statement)
  }

  func beginImmediateTransaction() throws {
    try execute("BEGIN IMMEDIATE TRANSACTION;")
  }

  func commitTransaction() throws {
    try execute("COMMIT;")
  }

  func rollbackTransaction() throws {
    try execute("ROLLBACK;")
  }

  private static func sqlitePath(from fileURL: URL) -> String {
    if fileURL.path == ":memory:" || fileURL.absoluteString == ":memory:" {
      return ":memory:"
    }
    return fileURL.path
  }
}

/// Bound lifetime wrapper around one prepared statement.
final class SQLiteStatement {
  private let handle: OpaquePointer
  private let database: OpaquePointer
  private var finalized = false

  init(handle: OpaquePointer, database: OpaquePointer) {
    self.handle = handle
    self.database = database
  }

  func bind(_ value: String, at index: Int32) throws {
    let result = value.withCString { cString in
      sqlite3_bind_text(handle, index, cString, -1, Self.sqliteTransient)
    }
    try checkBind(result)
  }

  func bind(_ value: Int64, at index: Int32) throws {
    try checkBind(sqlite3_bind_int64(handle, index, value))
  }

  func bind(_ value: Double, at index: Int32) throws {
    try checkBind(sqlite3_bind_double(handle, index, value))
  }

  func bind(_ value: Int, at index: Int32) throws {
    try bind(Int64(value), at: index)
  }

  func bind(_ value: UInt64, at index: Int32) throws {
    guard value <= UInt64(Int64.max) else {
      throw FocusPersistenceError.commitFailed("Sequence \(value) exceeds SQLite INTEGER range.")
    }
    try bind(Int64(value), at: index)
  }

  /// Steps once. Returns `true` when a row is available.
  @discardableResult
  func step() throws -> Bool {
    let result = sqlite3_step(handle)
    switch result {
    case SQLITE_ROW:
      return true
    case SQLITE_DONE:
      return false
    default:
      throw FocusPersistenceError.sqlite(
        code: result,
        message: String(cString: sqlite3_errmsg(database))
      )
    }
  }

  func text(at column: Int32) -> String? {
    guard let cString = sqlite3_column_text(handle, column) else {
      return nil
    }
    return String(cString: cString)
  }

  func int64(at column: Int32) -> Int64 {
    sqlite3_column_int64(handle, column)
  }

  func double(at column: Int32) -> Double {
    sqlite3_column_double(handle, column)
  }

  func finalize() {
    guard !finalized else { return }
    finalized = true
    sqlite3_finalize(handle)
  }

  private func checkBind(_ result: Int32) throws {
    guard result == SQLITE_OK else {
      throw FocusPersistenceError.sqlite(
        code: result,
        message: String(cString: sqlite3_errmsg(database))
      )
    }
  }

  /// `SQLITE_TRANSIENT` — SQLite copies the bound bytes.
  private static let sqliteTransient = unsafeBitCast(
    -1,
    to: sqlite3_destructor_type.self
  )
}
