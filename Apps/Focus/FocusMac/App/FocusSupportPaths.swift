import Foundation

/// Application Support layout for Focus macOS persistence.
enum FocusSupportPaths: Sendable {
  static let applicationSupportFolderName = "Focus"
  static let databaseFileName = "focus.sqlite3"

  /// `~/Library/Application Support/Focus/focus.sqlite3`
  static func databaseURL(
    fileManager: FileManager = .default
  ) throws -> URL {
    let root = try fileManager.url(
      for: .applicationSupportDirectory,
      in: .userDomainMask,
      appropriateFor: nil,
      create: true
    )
    let directory = root.appendingPathComponent(applicationSupportFolderName, isDirectory: true)
    try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory.appendingPathComponent(databaseFileName, isDirectory: false)
  }
}
