import FocusSession
import Foundation

/// JSON coding for persisted `SessionRuntime` and `OutcomeEvent` values.
///
/// Dates are encoded as UTC seconds since 1970 so restore does not depend on
/// local timezone or calendar preferences.
enum PersistenceCodec {
  static func encodeSnapshot(_ runtime: SessionRuntime) throws -> String {
    let data = try makeEncoder().encode(runtime)
    guard let string = String(data: data, encoding: .utf8) else {
      throw FocusPersistenceError.commitFailed("Snapshot JSON is not UTF-8.")
    }
    return string
  }

  static func decodeSnapshot(_ json: String) throws -> SessionRuntime {
    guard let data = json.data(using: .utf8) else {
      throw FocusPersistenceError.corruptSnapshot("Snapshot JSON is not UTF-8.")
    }
    do {
      return try makeDecoder().decode(SessionRuntime.self, from: data)
    } catch {
      throw FocusPersistenceError.corruptSnapshot(
        "Snapshot JSON could not be decoded: \(error.localizedDescription)"
      )
    }
  }

  static func encodeEvent(_ event: OutcomeEvent) throws -> String {
    let data = try makeEncoder().encode(event)
    guard let string = String(data: data, encoding: .utf8) else {
      throw FocusPersistenceError.commitFailed("Event JSON is not UTF-8.")
    }
    return string
  }

  static func decodeEvent(_ json: String) throws -> OutcomeEvent {
    guard let data = json.data(using: .utf8) else {
      throw FocusPersistenceError.corruptSnapshot("Event JSON is not UTF-8.")
    }
    do {
      return try makeDecoder().decode(OutcomeEvent.self, from: data)
    } catch {
      throw FocusPersistenceError.corruptSnapshot(
        "Event JSON could not be decoded: \(error.localizedDescription)"
      )
    }
  }

  private static func makeEncoder() -> JSONEncoder {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .secondsSince1970
    encoder.outputFormatting = [.sortedKeys]
    return encoder
  }

  private static func makeDecoder() -> JSONDecoder {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .secondsSince1970
    return decoder
  }
}
