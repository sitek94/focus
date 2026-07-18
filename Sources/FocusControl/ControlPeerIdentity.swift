import Foundation

#if canImport(Darwin)
  import Darwin
#else
  import Glibc
#endif

/// Verifies peer credentials on an accepted or connected Unix socket.
public protocol ControlPeerIdentityChecking: Sendable {
  /// Validate that `fileDescriptor` belongs to an acceptable peer.
  func verifyPeer(fileDescriptor: Int32) throws
}

public enum ControlPeerIdentityError: Error, Sendable, Equatable {
  case peerCheckFailed
  case uidMismatch(expected: UInt32, actual: UInt32)
  case unsupportedPlatform
}

/// Linux / portable fixture: same-UID assumption without `getpeereid`.
///
/// Unix-domain sockets on Linux are already scoped by filesystem permissions
/// when the parent directory is private. This checker records that the
/// portable trust model is “same local user” without calling Darwin APIs.
public struct SameUserPeerIdentityChecker: ControlPeerIdentityChecking {
  public init() {}

  public func verifyPeer(fileDescriptor: Int32) throws {
    guard fileDescriptor >= 0 else {
      throw ControlPeerIdentityError.peerCheckFailed
    }
    // Intentionally no getpeereid — Linux tests rely on private socket paths.
  }
}

#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
  /// Darwin peer check via `getpeereid` (same UID required).
  ///
  /// Wired on Mac in `FocusMacIntegrationTests` / the app listener. Portable
  /// Linux targets never import this path.
  public struct DarwinPeerIdentityChecker: ControlPeerIdentityChecking {
    private let expectedUID: uid_t

    public init(expectedUID: uid_t = getuid()) {
      self.expectedUID = expectedUID
    }

    public func verifyPeer(fileDescriptor: Int32) throws {
      var uid: uid_t = 0
      var gid: gid_t = 0
      let result = getpeereid(fileDescriptor, &uid, &gid)
      guard result == 0 else {
        throw ControlPeerIdentityError.peerCheckFailed
      }
      guard uid == expectedUID else {
        throw ControlPeerIdentityError.uidMismatch(
          expected: UInt32(expectedUID),
          actual: UInt32(uid)
        )
      }
    }
  }
#endif

/// Selects the platform-appropriate checker.
public enum ControlPeerIdentity: Sendable {
  public static func makeDefaultChecker() -> any ControlPeerIdentityChecking {
    #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
      return DarwinPeerIdentityChecker()
    #else
      return SameUserPeerIdentityChecker()
    #endif
  }
}
