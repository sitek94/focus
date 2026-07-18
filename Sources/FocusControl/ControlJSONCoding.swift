import Foundation

/// Shared JSON coding for focus-control envelopes (ISO-8601 dates, null optionals).
public enum ControlJSONCoding: Sendable {
  public static func makeEncoder() -> JSONEncoder {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.sortedKeys]
    return encoder
  }

  public static func makeDecoder() -> JSONDecoder {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return decoder
  }

  public static func encodeRequest(_ request: ControlRequest) throws -> Data {
    try makeEncoder().encode(request)
  }

  public static func decodeRequest(_ data: Data) throws -> ControlRequest {
    try makeDecoder().decode(ControlRequest.self, from: data)
  }

  public static func encodeResponse(_ response: ControlResponse) throws -> Data {
    try makeEncoder().encode(response)
  }

  public static func decodeResponse(_ data: Data) throws -> ControlResponse {
    try makeDecoder().decode(ControlResponse.self, from: data)
  }
}
