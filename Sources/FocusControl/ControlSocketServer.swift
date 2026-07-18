import Foundation

#if canImport(Darwin)
  import Darwin
#else
  import Glibc
#endif

/// Minimal Unix-domain server: accept → peer check → one framed request/response.
///
/// Accept/read/write use non-blocking sockets and short sleeps so cooperative
/// thread-pool executors are not stalled when multiple fixtures run in parallel.
public actor ControlSocketServer {
  public typealias Handler = @Sendable (ControlRequest) async -> ControlResponse

  private let socketPath: URL
  private let peerChecker: any ControlPeerIdentityChecking
  private let handler: Handler
  private var listenFD: Int32 = -1
  private var acceptTask: Task<Void, Never>?
  private var isRunning = false

  public init(
    socketPath: URL,
    peerChecker: any ControlPeerIdentityChecking = ControlPeerIdentity.makeDefaultChecker(),
    handler: @escaping Handler
  ) {
    self.socketPath = socketPath
    self.peerChecker = peerChecker
    self.handler = handler
  }

  public var path: URL { socketPath }

  public func start() throws {
    guard !isRunning else { return }
    let parent = socketPath.deletingLastPathComponent()
    try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
    try ControlSocketPath.validateParentDirectory(parent)
    try ControlSocketPath.validatePathLength(socketPath.path)

    let fd = try UnixSocketIO.makeStreamSocket()
    do {
      try UnixSocketIO.bindListen(fd: fd, path: socketPath.path)
      try Self.setNonBlocking(fd)
    } catch {
      close(fd)
      throw error
    }
    listenFD = fd
    isRunning = true

    acceptTask = Task { [weak self] in
      await self?.acceptLoop()
    }
  }

  public func stop() {
    isRunning = false
    acceptTask?.cancel()
    acceptTask = nil
    if listenFD >= 0 {
      close(listenFD)
      listenFD = -1
    }
    try? FileManager.default.removeItem(at: socketPath)
  }

  deinit {
    if listenFD >= 0 {
      close(listenFD)
    }
  }

  private func acceptLoop() async {
    while !Task.isCancelled && isRunning {
      let currentFD = listenFD
      guard currentFD >= 0 else { return }

      let clientFD = posixAccept(currentFD, nil, nil)
      if clientFD < 0 {
        if errno == EAGAIN || errno == EWOULDBLOCK || errno == EINTR {
          try? await Task.sleep(for: .milliseconds(10))
          continue
        }
        if Task.isCancelled || !isRunning { return }
        try? await Task.sleep(for: .milliseconds(10))
        continue
      }

      await handleClient(clientFD)
    }
  }

  private func handleClient(_ clientFD: Int32) async {
    defer { close(clientFD) }
    do {
      try peerChecker.verifyPeer(fileDescriptor: clientFD)
      try Self.setNonBlocking(clientFD)

      let payload = try await Self.readFrameNonBlocking(fd: clientFD)
      let request = try ControlJSONCoding.decodeRequest(payload)
      let response = await handler(request)
      let responseData = try ControlJSONCoding.encodeResponse(response)
      try await Self.writeFrameNonBlocking(fd: clientFD, payload: responseData)
    } catch {
      return
    }
  }

  private static func setNonBlocking(_ fd: Int32) throws {
    let flags = fcntl(fd, F_GETFL)
    guard flags >= 0 else {
      throw ControlTransportError.socket("F_GETFL failed: \(errno)")
    }
    guard fcntl(fd, F_SETFL, flags | O_NONBLOCK) == 0 else {
      throw ControlTransportError.socket("F_SETFL O_NONBLOCK failed: \(errno)")
    }
  }

  private static func readFrameNonBlocking(fd: Int32) async throws -> Data {
    let header = try await readExactNonBlocking(fd: fd, count: ControlFraming.lengthPrefixSize)
    let size: Int
    do {
      size = try ControlFraming.decodeLengthPrefix(header)
    } catch let framing as ControlFraming.Error {
      throw ControlTransportError.framing(framing)
    }
    return try await readExactNonBlocking(fd: fd, count: size)
  }

  private static func writeFrameNonBlocking(fd: Int32, payload: Data) async throws {
    let frame: Data
    do {
      frame = try ControlFraming.frame(payload)
    } catch let framing as ControlFraming.Error {
      throw ControlTransportError.framing(framing)
    }
    try await writeAllNonBlocking(fd: fd, data: frame)
  }

  private static func readExactNonBlocking(fd: Int32, count: Int) async throws -> Data {
    var data = Data(count: count)
    var offset = 0
    var idleSpins = 0
    while offset < count {
      if Task.isCancelled { throw ControlTransportError.cancelled }
      let readCount = data.withUnsafeMutableBytes { buffer -> Int in
        guard let base = buffer.baseAddress else { return -1 }
        return read(fd, base.advanced(by: offset), count - offset)
      }
      if readCount == 0 {
        throw ControlTransportError.socket("unexpected EOF")
      }
      if readCount < 0 {
        if errno == EINTR { continue }
        if errno == EAGAIN || errno == EWOULDBLOCK {
          idleSpins += 1
          if idleSpins > 500 {
            throw ControlTransportError.commandTimeout
          }
          try? await Task.sleep(for: .milliseconds(5))
          continue
        }
        throw ControlTransportError.socket("read() failed: \(errno)")
      }
      idleSpins = 0
      offset += readCount
    }
    return data
  }

  private static func writeAllNonBlocking(fd: Int32, data: Data) async throws {
    var sent = 0
    var idleSpins = 0
    let total = data.count
    while sent < total {
      if Task.isCancelled { throw ControlTransportError.cancelled }
      let result = data.withUnsafeBytes { buffer -> Int in
        guard let base = buffer.baseAddress else { return -1 }
        return write(fd, base.advanced(by: sent), total - sent)
      }
      if result < 0 {
        if errno == EINTR { continue }
        if errno == EAGAIN || errno == EWOULDBLOCK {
          idleSpins += 1
          if idleSpins > 500 {
            throw ControlTransportError.commandTimeout
          }
          try? await Task.sleep(for: .milliseconds(5))
          continue
        }
        throw ControlTransportError.socket("write() failed: \(errno)")
      }
      idleSpins = 0
      sent += result
    }
  }
}

private func posixAccept(
  _ fd: Int32,
  _ address: UnsafeMutablePointer<sockaddr>?,
  _ length: UnsafeMutablePointer<socklen_t>?
) -> Int32 {
  accept(fd, address, length)
}
