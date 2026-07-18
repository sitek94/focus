import Foundation

/// Four-byte big-endian length-prefixed UTF-8 JSON frames with a 64 KiB cap.
public enum ControlFraming: Sendable {
  public static let maxPayloadSize = 64 * 1024
  public static let lengthPrefixSize = 4

  public enum Error: Swift.Error, Sendable, Equatable {
    case oversized(declaredSize: Int)
    case malformedLength
    case incompleteHeader
    case incompletePayload(expected: Int, received: Int)
    case emptyPayload
  }

  /// Encode `payload` as `[u32be length][payload]`.
  public static func frame(_ payload: Data) throws -> Data {
    guard payload.count > 0 else {
      throw Error.emptyPayload
    }
    guard payload.count <= maxPayloadSize else {
      throw Error.oversized(declaredSize: payload.count)
    }
    var frame = Data(capacity: lengthPrefixSize + payload.count)
    var length = UInt32(payload.count).bigEndian
    withUnsafeBytes(of: &length) { frame.append(contentsOf: $0) }
    frame.append(payload)
    return frame
  }

  /// Decode a big-endian length prefix. Rejects zero and oversized declarations.
  public static func decodeLengthPrefix(_ header: Data) throws -> Int {
    guard header.count == lengthPrefixSize else {
      throw Error.incompleteHeader
    }
    let length = header.withUnsafeBytes { buffer -> UInt32 in
      buffer.loadUnaligned(as: UInt32.self).bigEndian
    }
    let size = Int(length)
    guard size > 0 else {
      throw Error.malformedLength
    }
    guard size <= maxPayloadSize else {
      throw Error.oversized(declaredSize: size)
    }
    return size
  }

  /// Consume one complete frame from `buffer`, returning the payload and remainder.
  public static func consumeFrame(from buffer: inout Data) throws -> Data? {
    guard buffer.count >= lengthPrefixSize else {
      return nil
    }
    let header = buffer.prefix(lengthPrefixSize)
    let size = try decodeLengthPrefix(Data(header))
    let total = lengthPrefixSize + size
    guard buffer.count >= total else {
      return nil
    }
    let payload = Data(buffer.subdata(in: lengthPrefixSize..<total))
    buffer.removeSubrange(0..<total)
    return payload
  }
}
