import CSQLite

/// Portable Focus persistence module marker and CSQLite link probe.
public enum FocusPersistenceModule {
  public static let moduleName = "FocusPersistence"

  /// Confirms the system SQLite library is linkable on this platform.
  public static var sqliteLinked: Bool {
    sqlite3_libversion_number() > 0
  }
}
