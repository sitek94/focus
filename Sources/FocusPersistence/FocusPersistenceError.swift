import Foundation

/// Failures from opening, migrating, or reading the Focus SQLite store.
public enum FocusPersistenceError: Error, Sendable, Equatable {
  /// Underlying SQLite API failure.
  case sqlite(code: Int32, message: String)
  /// `runtime_snapshot` payload exists but cannot be decoded into `SessionRuntime`.
  case corruptSnapshot(String)
  /// Schema metadata or migration path is invalid.
  case schema(String)
  /// A transactional commit could not be completed.
  case commitFailed(String)
}
