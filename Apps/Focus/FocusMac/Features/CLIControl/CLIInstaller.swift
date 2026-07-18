import Foundation

/// Installs / repairs the user-owned `focus` CLI symlink (PLAN §8 install story).
@MainActor
final class CLIInstaller {
  enum State: Equatable, Sendable {
    case notInstalled
    case installed(symlinkURL: URL, targetURL: URL)
    case needsRepair(symlinkURL: URL, expectedTarget: URL)
    case blockedByTranslocation
    case bundledToolMissing
  }

  enum InstallError: Error, Equatable, Sendable {
    case translocated
    case bundledToolMissing
    case symlinkFailed(String)
  }

  private let bundle: Bundle
  private let fileManager: FileManager
  private let homeDirectory: () -> URL

  init(
    bundle: Bundle = .main,
    fileManager: FileManager = .default,
    homeDirectory: @escaping () -> URL = {
      FileManager.default.homeDirectoryForCurrentUser
    }
  ) {
    self.bundle = bundle
    self.fileManager = fileManager
    self.homeDirectory = homeDirectory
  }

  /// Preferred install location: `~/.local/bin/focus`.
  var preferredSymlinkURL: URL {
    CLIInstallPaths.preferredSymlinkURL(homeDirectory: homeDirectory())
  }

  var bundledCLIURL: URL? {
    CLIInstallPaths.bundledCLIURL(in: bundle)
  }

  var isTranslocated: Bool {
    CLIInstallPaths.isTranslocated(bundleURL: bundle.bundleURL)
  }

  func currentState() -> State {
    if isTranslocated {
      return .blockedByTranslocation
    }
    guard let bundled = bundledCLIURL else {
      return .bundledToolMissing
    }
    let symlink = preferredSymlinkURL
    guard fileManager.fileExists(atPath: symlink.path) else {
      return .notInstalled
    }
    if let destination = try? fileManager.destinationOfSymbolicLink(atPath: symlink.path) {
      let resolved: URL
      if destination.hasPrefix("/") {
        resolved = URL(fileURLWithPath: destination).standardizedFileURL
      } else {
        resolved =
          URL(
            fileURLWithPath: destination,
            relativeTo: symlink.deletingLastPathComponent()
          ).standardizedFileURL
      }
      if resolved == bundled.standardizedFileURL {
        return .installed(symlinkURL: symlink, targetURL: bundled)
      }
      return .needsRepair(symlinkURL: symlink, expectedTarget: bundled)
    }
    return .needsRepair(symlinkURL: symlink, expectedTarget: bundled)
  }

  @discardableResult
  func installOrRepair() throws -> URL {
    if isTranslocated {
      throw InstallError.translocated
    }
    guard let bundled = bundledCLIURL else {
      throw InstallError.bundledToolMissing
    }
    let symlink = preferredSymlinkURL
    let parent = symlink.deletingLastPathComponent()
    do {
      try fileManager.createDirectory(at: parent, withIntermediateDirectories: true)
      if fileManager.fileExists(atPath: symlink.path) {
        try fileManager.removeItem(at: symlink)
      }
      try fileManager.createSymbolicLink(
        atPath: symlink.path,
        withDestinationPath: bundled.path
      )
      return symlink
    } catch let error as InstallError {
      throw error
    } catch {
      throw InstallError.symlinkFailed(String(describing: error))
    }
  }

  /// Shell instruction when `~/.local/bin` is missing from PATH.
  func pathInstructionIfNeeded(
    pathEnvironment: String? = ProcessInfo.processInfo.environment["PATH"]
  )
    -> String?
  {
    let bin = preferredSymlinkURL.deletingLastPathComponent().path
    let entries = (pathEnvironment ?? "").split(separator: ":").map(String.init)
    if entries.contains(bin) {
      return nil
    }
    return "Add \(bin) to PATH, for example: export PATH=\"\(bin):$PATH\""
  }
}

/// Pure path helpers for CLI install/repair (testable without AppKit).
enum CLIInstallPaths: Sendable {
  static let relativeBinComponents = [".local", "bin"]
  static let toolName = "focus"

  static func preferredSymlinkURL(homeDirectory: URL) -> URL {
    relativeBinComponents.reduce(homeDirectory) { partial, component in
      partial.appendingPathComponent(component, isDirectory: true)
    }
    .appendingPathComponent(toolName, isDirectory: false)
  }

  static func bundledCLIURL(in bundle: Bundle) -> URL? {
    let macos = bundle.bundleURL
      .appendingPathComponent("Contents", isDirectory: true)
      .appendingPathComponent("MacOS", isDirectory: true)
      .appendingPathComponent(toolName, isDirectory: false)
    if FileManager.default.isExecutableFile(atPath: macos.path) {
      return macos
    }
    // Debug / non-bundled runs may resolve via executable sibling.
    if let executable = bundle.executableURL?.deletingLastPathComponent()
      .appendingPathComponent(toolName, isDirectory: false),
      FileManager.default.isExecutableFile(atPath: executable.path)
    {
      return executable
    }
    return nil
  }

  /// App Translocation / DMG path — installation must be refused.
  static func isTranslocated(bundleURL: URL) -> Bool {
    let path = bundleURL.path
    if path.contains("/AppTranslocation/") {
      return true
    }
    // Mounted disk images commonly appear under /Volumes and are not durable.
    if path.hasPrefix("/Volumes/") {
      return true
    }
    return false
  }
}
