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
  /// Path exists but is not a Unix-domain socket (server must not unlink it).
  case endpointNotSocket(URL)
  /// Path exists but is not owned by the current UID (server must not unlink it).
  case endpointNotOwnedByCurrentUser(URL)
  case unlinkFailed(URL, errno: Int32)
  case lstatFailed(URL, errno: Int32)
}

/// Shared socket filename and path rules.
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
  ///
  /// Uses `lstat` (does not follow symlinks). Privacy means no group/other
  /// read/write/execute bits: `(mode & 0o077) == 0`.
  public static func validateParentDirectory(_ parent: URL) throws {
    var info = stat()
    let result = lstat(parent.path, &info)
    guard result == 0 else {
      if errno == ENOENT {
        throw ControlSocketPathError.parentMissing(parent)
      }
      throw ControlSocketPathError.lstatFailed(parent, errno: errno)
    }

    guard (info.st_mode & S_IFMT) == S_IFDIR else {
      throw ControlSocketPathError.parentNotDirectory(parent)
    }
    guard info.st_uid == getuid() else {
      throw ControlSocketPathError.parentNotOwnedByCurrentUser(parent)
    }
    // Reject any group/other access bits (0700-style privacy).
    guard (info.st_mode & mode_t(0o077)) == 0 else {
      throw ControlSocketPathError.parentNotPrivate(parent)
    }
  }

  /// Ensure `directory` exists as a current-UID `0700` directory (for servers/tests).
  public static func ensurePrivateDirectory(_ directory: URL) throws {
    let fm = FileManager.default
    if !fm.fileExists(atPath: directory.path) {
      try fm.createDirectory(at: directory, withIntermediateDirectories: true)
    }
    try setPrivateDirectoryMode(directory)
    try validateParentDirectory(directory)
  }

  /// Force POSIX mode `0700` on an existing directory.
  public static func setPrivateDirectoryMode(_ directory: URL) throws {
    if chmod(directory.path, mode_t(0o700)) != 0 {
      throw ControlSocketPathError.lstatFailed(directory, errno: errno)
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

  /// `lstat` the endpoint. Returns `nil` when the path does not exist.
  public static func inspectEndpoint(_ url: URL) throws -> EndpointInfo? {
    var info = stat()
    let result = lstat(url.path, &info)
    guard result == 0 else {
      if errno == ENOENT {
        return nil
      }
      throw ControlSocketPathError.lstatFailed(url, errno: errno)
    }
    return EndpointInfo(
      url: url,
      isSocket: (info.st_mode & S_IFMT) == S_IFSOCK,
      ownerUID: info.st_uid
    )
  }

  /// Unlink a stale endpoint only when it is a same-owner Unix socket.
  ///
  /// No-op when the path is absent. Throws when a non-socket or foreign-owned
  /// path occupies the location — callers must not remove those.
  public static func unlinkStaleSocketIfSafe(_ url: URL) throws {
    guard let endpoint = try inspectEndpoint(url) else {
      return
    }
    guard endpoint.isSocket else {
      throw ControlSocketPathError.endpointNotSocket(url)
    }
    guard endpoint.ownerUID == getuid() else {
      throw ControlSocketPathError.endpointNotOwnedByCurrentUser(url)
    }
    if unlink(url.path) != 0 {
      if errno == ENOENT {
        return
      }
      throw ControlSocketPathError.unlinkFailed(url, errno: errno)
    }
  }

  /// Metadata from a non-following `lstat` of a control endpoint path.
  public struct EndpointInfo: Sendable, Equatable {
    public var url: URL
    public var isSocket: Bool
    public var ownerUID: uid_t

    public init(url: URL, isSocket: Bool, ownerUID: uid_t) {
      self.url = url
      self.isSocket = isSocket
      self.ownerUID = ownerUID
    }

    public var isCurrentUserOwned: Bool {
      ownerUID == getuid()
    }
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
