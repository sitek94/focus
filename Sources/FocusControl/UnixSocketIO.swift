import Foundation

#if canImport(Darwin)
  import Darwin
#else
  import Glibc
#endif

/// Low-level POSIX Unix-domain socket helpers shared by client and server.
enum UnixSocketIO {
  static func makeStreamSocket() throws -> Int32 {
    // Avoid process termination when the peer closes mid-write (Linux default SIGPIPE).
    signal(SIGPIPE, SIG_IGN)
    #if os(Linux)
      let fd = socket(AF_UNIX, Int32(SOCK_STREAM.rawValue), 0)
    #else
      let fd = socket(AF_UNIX, SOCK_STREAM, 0)
    #endif
    guard fd >= 0 else {
      throw ControlTransportError.socket("socket() failed: \(errno)")
    }
    #if canImport(Darwin)
      var on: Int32 = 1
      _ = setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &on, socklen_t(MemoryLayout<Int32>.size))
    #endif
    return fd
  }

  static func setTimeouts(fd: Int32, duration: Duration) throws {
    var value = ControlTimeouts.makeTimeval(for: duration)
    let size = socklen_t(MemoryLayout<timeval>.size)
    if setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &value, size) != 0 {
      throw ControlTransportError.socket("SO_RCVTIMEO failed: \(errno)")
    }
    if setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &value, size) != 0 {
      throw ControlTransportError.socket("SO_SNDTIMEO failed: \(errno)")
    }
  }

  static func withUnixAddress(
    path: String,
    body: (UnsafePointer<sockaddr>, socklen_t) throws -> Void
  ) throws {
    try ControlSocketPath.validatePathLength(path)
    var addr = sockaddr_un()
    memset(&addr, 0, MemoryLayout<sockaddr_un>.size)
    addr.sun_family = sa_family_t(AF_UNIX)
    let pathBytes = Array(path.utf8)
    let capacity = MemoryLayout.size(ofValue: addr.sun_path)
    guard pathBytes.count < capacity else {
      throw ControlSocketPathError.pathTooLong(
        byteCount: pathBytes.count,
        limit: capacity - 1
      )
    }
    withUnsafeMutablePointer(to: &addr.sun_path) { pointer in
      let raw = UnsafeMutableRawPointer(pointer).assumingMemoryBound(to: CChar.self)
      for (index, byte) in pathBytes.enumerated() {
        raw[index] = CChar(bitPattern: byte)
      }
      raw[pathBytes.count] = 0
    }

    let length = socklen_t(MemoryLayout<sockaddr_un>.size)
    try withUnsafePointer(to: &addr) { pointer in
      try pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
        try body(sockaddrPointer, length)
      }
    }
  }

  static func connect(fd: Int32, path: String, timeout: Duration) throws {
    let flags = fcntl(fd, F_GETFL)
    guard flags >= 0 else {
      throw ControlTransportError.socket("F_GETFL failed: \(errno)")
    }
    guard fcntl(fd, F_SETFL, flags | O_NONBLOCK) == 0 else {
      throw ControlTransportError.socket("F_SETFL O_NONBLOCK failed: \(errno)")
    }

    var connectErrno: Int32 = 0
    do {
      try withUnixAddress(path: path) { address, length in
        let result = posixConnect(fd, address, length)
        if result == 0 {
          connectErrno = 0
          return
        }
        connectErrno = errno
      }
    } catch let pathError as ControlSocketPathError {
      throw ControlTransportError.path(pathError)
    }

    if connectErrno != 0 && connectErrno != EINPROGRESS && connectErrno != EAGAIN {
      if connectErrno == ECONNREFUSED || connectErrno == ENOENT {
        throw ControlTransportError.appNotRunning
      }
      throw ControlTransportError.socket("connect() failed: \(connectErrno)")
    }

    if connectErrno != 0 {
      var pollFD = pollfd(fd: fd, events: Int16(POLLOUT), revents: 0)
      let milliseconds = max(1, Int32(timeout.millisecondCount))
      let pollResult = poll(&pollFD, 1, milliseconds)
      if pollResult == 0 {
        throw ControlTransportError.connectTimeout
      }
      if pollResult < 0 {
        throw ControlTransportError.socket("poll() failed: \(errno)")
      }
      var errorCode: Int32 = 0
      var length = socklen_t(MemoryLayout<Int32>.size)
      if getsockopt(fd, SOL_SOCKET, SO_ERROR, &errorCode, &length) != 0 {
        throw ControlTransportError.socket("getsockopt(SO_ERROR) failed: \(errno)")
      }
      if errorCode != 0 {
        if errorCode == ECONNREFUSED || errorCode == ENOENT {
          throw ControlTransportError.appNotRunning
        }
        throw ControlTransportError.socket("connect SO_ERROR: \(errorCode)")
      }
    }

    guard fcntl(fd, F_SETFL, flags) == 0 else {
      throw ControlTransportError.socket("F_SETFL restore failed: \(errno)")
    }
  }

  static func bindListen(fd: Int32, path: String) throws {
    try? FileManager.default.removeItem(atPath: path)
    do {
      try withUnixAddress(path: path) { address, length in
        if posixBind(fd, address, length) != 0 {
          throw ControlTransportError.socket("bind() failed: \(errno)")
        }
      }
    } catch let pathError as ControlSocketPathError {
      throw ControlTransportError.path(pathError)
    } catch let transport as ControlTransportError {
      throw transport
    }
    if listen(fd, 16) != 0 {
      throw ControlTransportError.socket("listen() failed: \(errno)")
    }
  }

  static func acceptClient(fd: Int32) throws -> Int32 {
    let client = posixAccept(fd, nil, nil)
    guard client >= 0 else {
      if errno == EAGAIN || errno == EWOULDBLOCK || errno == EINTR {
        throw ControlTransportError.commandTimeout
      }
      throw ControlTransportError.socket("accept() failed: \(errno)")
    }
    return client
  }

  static func writeAll(fd: Int32, data: Data) throws {
    try data.withUnsafeBytes { buffer in
      guard let base = buffer.baseAddress else {
        throw ControlTransportError.socket("empty write buffer")
      }
      var sent = 0
      let total = buffer.count
      while sent < total {
        let result = write(fd, base.advanced(by: sent), total - sent)
        if result < 0 {
          if errno == EINTR { continue }
          if errno == EAGAIN || errno == EWOULDBLOCK {
            throw ControlTransportError.commandTimeout
          }
          throw ControlTransportError.socket("write() failed: \(errno)")
        }
        sent += Int(result)
      }
    }
  }

  static func readExact(fd: Int32, count: Int) throws -> Data {
    var data = Data(count: count)
    var offset = 0
    while offset < count {
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
          throw ControlTransportError.commandTimeout
        }
        throw ControlTransportError.socket("read() failed: \(errno)")
      }
      offset += readCount
    }
    return data
  }

  static func readFrame(fd: Int32) throws -> Data {
    let header = try readExact(fd: fd, count: ControlFraming.lengthPrefixSize)
    let size: Int
    do {
      size = try ControlFraming.decodeLengthPrefix(header)
    } catch let framing as ControlFraming.Error {
      throw ControlTransportError.framing(framing)
    }
    return try readExact(fd: fd, count: size)
  }

  static func writeFrame(fd: Int32, payload: Data) throws {
    let frame: Data
    do {
      frame = try ControlFraming.frame(payload)
    } catch let framing as ControlFraming.Error {
      throw ControlTransportError.framing(framing)
    }
    try writeAll(fd: fd, data: frame)
  }
}

private func posixConnect(
  _ fd: Int32,
  _ address: UnsafePointer<sockaddr>,
  _ length: socklen_t
) -> Int32 {
  connect(fd, address, length)
}

private func posixBind(
  _ fd: Int32,
  _ address: UnsafePointer<sockaddr>,
  _ length: socklen_t
) -> Int32 {
  bind(fd, address, length)
}

private func posixAccept(
  _ fd: Int32,
  _ address: UnsafeMutablePointer<sockaddr>?,
  _ length: UnsafeMutablePointer<socklen_t>?
) -> Int32 {
  accept(fd, address, length)
}

extension Duration {
  fileprivate var millisecondCount: Int64 {
    let components = self.components
    let msFromSeconds = components.seconds * 1_000
    let msFromAttoseconds = components.attoseconds / 1_000_000_000_000_000
    return msFromSeconds + msFromAttoseconds
  }
}
