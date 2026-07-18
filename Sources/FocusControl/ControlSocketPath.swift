import Foundation

#if canImport(Darwin)
  import Darwin
#else
  import Glibc
#endif

/// Resolves the per-user Unix-domain control socket path.
public protocol ControlSocketPathResolving: Sendable {
  func resolveSocketURL() throws -> URL
}

/// Errors while validating or resolving a control socket path.
public enum ControlSocketPathError: Error, Sendable, Equatable {
  case pathTooLong(byteCount: Int, limit: Int)
  case parentMissing(URL)
  case parentNotDirectory(URL)
  case parentNotOwnedByCurrentUser(URL)
  case parentNotPrivate(URL)
  case missingInjectedPath
  case darwinTempDirectoryUnavailable
}

/// Shared socket filename and path rules (PLAN §8).
public enum ControlSocketPath: Sendable {
  /// Flat socket filename under the per-user temp directory.
  public static let fileName = "com.macieksitkowski.focus.macos.control.sock"

  /// Darwin `sockaddr_un.sun_path` UTF-8 byte limit (NUL excluded).
  public static let maxPathByteLength = 104

  /// Debug/test environment key for an absolute injected socket path.
  ///
  /// Honored only in `DEBUG` builds. Release builds ignore this override.
  public static let injectedEnvironmentKey = "FOCUS_CONTROL_SOCKET"

  /// Validate UTF-8 byte length against the Darwin sun_path limit.
  public static func validatePathLength(_ path: String) throws {
    let byteCount = path.utf8.count
    guard byteCount <= maxPathByteLength else {
      throw ControlSocketPathError.pathTooLong(
        byteCount: byteCount,
        limit: maxPathByteLength
      )
    }
  }

  /// Require `parent` to be a private directory owned by the current UID.
  public static func validateParentDirectory(_ parent: URL) throws {
    var isDirectory: ObjCBool = false
    guard
      FileManager.default.fileExists(
        atPath: parent.path,
        isDirectory: &isDirectory
      ), isDirectory.boolValue
    else {
      if FileManager.default.fileExists(atPath: parent.path) {
        throw ControlSocketPathError.parentNotDirectory(parent)
      }
      throw ControlSocketPathError.parentMissing(parent)
    }

    let attrs = try FileManager.default.attributesOfItem(atPath: parent.path)
    if let owner = attrs[.ownerAccountID] as? NSNumber {
      let current = getuid()
      guard owner.uint32Value == current else {
        throw ControlSocketPathError.parentNotOwnedByCurrentUser(parent)
      }
    }
    if let posix = attrs[.posixPermissions] as? NSNumber {
      let mode = mode_t(posix.uint16Value)
      // Reject group/other write — require a private directory.
      if mode & S_IWGRP != 0 || mode & S_IWOTH != 0 {
        throw ControlSocketPathError.parentNotPrivate(parent)
      }
    }
  }

  /// Compose `parent/fileName` and validate length.
  public static func socketURL(inParent parent: URL) throws -> URL {
    let url = parent.appendingPathComponent(fileName, isDirectory: false)
    try validatePathLength(url.path)
    try validateParentDirectory(parent)
    return url
  }

  /// Resolve an injected absolute path (caller still validates parent).
  public static func injectedSocketURL(path: String) throws -> URL {
    let url = URL(fileURLWithPath: path)
    try validatePathLength(url.path)
    let parent = url.deletingLastPathComponent()
    try validateParentDirectory(parent)
    return url
  }
}

/// Injected absolute socket path — primary resolver for Linux tests.
public struct InjectedControlSocketPathResolver: ControlSocketPathResolving {
  private let path: String

  public init(path: String) {
    self.path = path
  }

  public init(url: URL) {
    self.path = url.path
  }

  public func resolveSocketURL() throws -> URL {
    try ControlSocketPath.injectedSocketURL(path: path)
  }
}

/// Resolves via `FOCUS_CONTROL_SOCKET` in DEBUG builds only.
public struct EnvironmentControlSocketPathResolver: ControlSocketPathResolving {
  private let environment: [String: String]

  public init(environment: [String: String] = ProcessInfo.processInfo.environment) {
    self.environment = environment
  }

  public func resolveSocketURL() throws -> URL {
    #if DEBUG
      guard let raw = environment[ControlSocketPath.injectedEnvironmentKey],
        !raw.isEmpty
      else {
        throw ControlSocketPathError.missingInjectedPath
      }
      return try ControlSocketPath.injectedSocketURL(path: raw)
    #else
      throw ControlSocketPathError.missingInjectedPath
    #endif
  }
}

#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
  /// Darwin resolver using `_CS_DARWIN_USER_TEMP_DIR`.
  ///
  /// Prefer this over `NSTemporaryDirectory()` unless that API already resolves
  /// to a private non-`/tmp` directory. Real Mac integration wires this into the
  /// app and CLI; Linux builds never compile this type.
  public struct DarwinControlSocketPathResolver: ControlSocketPathResolving {
    public init() {}

    public func resolveSocketURL() throws -> URL {
      guard let directory = Self.darwinUserTempDirectory() else {
        throw ControlSocketPathError.darwinTempDirectoryUnavailable
      }
      return try ControlSocketPath.socketURL(inParent: directory)
    }

    /// `_CS_DARWIN_USER_TEMP_DIR` → private per-user temporary directory.
    public static func darwinUserTempDirectory() -> URL? {
      let size = confstr(_CS_DARWIN_USER_TEMP_DIR, nil, 0)
      guard size > 0 else { return nil }
      var buffer = [CChar](repeating: 0, count: size)
      let written = confstr(_CS_DARWIN_USER_TEMP_DIR, &buffer, size)
      guard written > 0 else { return nil }
      let path = String(cString: buffer)
      guard !path.isEmpty else { return nil }
      return URL(fileURLWithPath: path, isDirectory: true)
    }
  }
#endif

/// Platform-default resolver: DEBUG env override, else Darwin temp on Apple.
public struct DefaultControlSocketPathResolver: ControlSocketPathResolving {
  private let environment: [String: String]

  public init(environment: [String: String] = ProcessInfo.processInfo.environment) {
    self.environment = environment
  }

  public func resolveSocketURL() throws -> URL {
    #if DEBUG
      if let raw = environment[ControlSocketPath.injectedEnvironmentKey], !raw.isEmpty {
        return try ControlSocketPath.injectedSocketURL(path: raw)
      }
    #endif
    #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
      return try DarwinControlSocketPathResolver().resolveSocketURL()
    #else
      throw ControlSocketPathError.missingInjectedPath
    #endif
  }
}
