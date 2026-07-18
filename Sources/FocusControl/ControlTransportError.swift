import Foundation

/// Transport and client-side failures before a response is available.
public enum ControlTransportError: Error, Sendable, Equatable {
  case appNotRunning
  case connectTimeout
  case commandTimeout
  case cancelled
  case permissionFailure
  case protocolMismatch
  case framing(ControlFraming.Error)
  case decoding(String)
  case encoding(String)
  case socket(String)
  case path(ControlSocketPathError)
}

extension ControlExitCode {
  /// Map a client-side transport failure onto an exit code.
  public static func from(transport error: ControlTransportError) -> ControlExitCode {
    switch error {
    case .appNotRunning:
      return .appNotRunning
    case .connectTimeout, .commandTimeout:
      return .timeout
    case .cancelled:
      return .internalError
    case .permissionFailure:
      return .permissionFailure
    case .protocolMismatch:
      return .protocolMismatch
    case .framing, .decoding, .encoding, .socket, .path:
      return .internalError
    }
  }
}
