import CSQLite

/// SQLite-backed persistence seam (schema and store land in a later checkpoint).
public enum FocusPersistenceModule {
  public static let moduleName = "FocusPersistence"

  /// Confirms the system SQLite library is linkable on this platform.
  public static var sqliteLinked: Bool {
    sqlite3_libversion_number() > 0
  }
}
