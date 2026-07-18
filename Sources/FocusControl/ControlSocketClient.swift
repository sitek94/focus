import Foundation

#if canImport(Darwin)
  import Darwin
#else
  import Glibc
#endif

/// One-request-per-connection Unix-domain client.
public struct ControlSocketClient: Sendable {
  public var socketPath: URL
  public var timeouts: ControlTimeouts
  public var peerChecker: any ControlPeerIdentityChecking

  public init(
    socketPath: URL,
    timeouts: ControlTimeouts = .default,
    peerChecker: any ControlPeerIdentityChecking = ControlPeerIdentity.makeDefaultChecker()
  ) {
    self.socketPath = socketPath
    self.timeouts = timeouts
    self.peerChecker = peerChecker
  }

  /// Connect, send `request`, read one framed response, disconnect.
  ///
  /// Blocking POSIX work runs on a detached thread so cooperative executors
  /// hosting `ControlSocketServer` accept loops are not starved.
  public func send(_ request: ControlRequest) async throws -> ControlResponse {
    let socketPath = self.socketPath
    let timeouts = self.timeouts
    let peerChecker = self.peerChecker
    return try await withCheckedThrowingContinuation { continuation in
      Thread.detachNewThread {
        do {
          let response = try Self.sendBlocking(
            request: request,
            socketPath: socketPath,
            timeouts: timeouts,
            peerChecker: peerChecker
          )
          continuation.resume(returning: response)
        } catch {
          continuation.resume(throwing: error)
        }
      }
    }
  }

  /// Synchronous send for CLI subprocesses and unit tests that already isolate IO.
  public func sendBlocking(_ request: ControlRequest) throws -> ControlResponse {
    try Self.sendBlocking(
      request: request,
      socketPath: socketPath,
      timeouts: timeouts,
      peerChecker: peerChecker
    )
  }

  private static func sendBlocking(
    request: ControlRequest,
    socketPath: URL,
    timeouts: ControlTimeouts,
    peerChecker: any ControlPeerIdentityChecking
  ) throws -> ControlResponse {
    let payload: Data
    do {
      payload = try ControlJSONCoding.encodeRequest(request)
    } catch {
      throw ControlTransportError.encoding(String(describing: error))
    }

    let fd = try UnixSocketIO.makeStreamSocket()
    defer { close(fd) }

    do {
      try UnixSocketIO.connect(
        fd: fd,
        path: socketPath.path,
        timeout: timeouts.connect
      )
      try peerChecker.verifyPeer(fileDescriptor: fd)
      try UnixSocketIO.setTimeouts(fd: fd, duration: timeouts.command)
      try UnixSocketIO.writeFrame(fd: fd, payload: payload)
      let responseData = try UnixSocketIO.readFrame(fd: fd)
      let response: ControlResponse
      do {
        response = try ControlJSONCoding.decodeResponse(responseData)
      } catch {
        throw ControlTransportError.decoding(String(describing: error))
      }
      if !response.protocol.isCompatibleMajor {
        throw ControlTransportError.protocolMismatch
      }
      return response
    } catch let peer as ControlPeerIdentityError {
      switch peer {
      case .uidMismatch, .peerCheckFailed, .unsupportedPlatform:
        throw ControlTransportError.permissionFailure
      }
    }
  }
}
