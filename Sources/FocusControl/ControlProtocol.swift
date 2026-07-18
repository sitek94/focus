import Foundation

/// Wire name and major/minor for the focus-control protocol.
public struct ControlProtocolInfo: Codable, Sendable, Equatable {
  public var name: String
  public var major: Int
  public var minor: Int

  public init(name: String, major: Int, minor: Int) {
    self.name = name
    self.major = major
    self.minor = minor
  }

  /// Current protocol identity (`focus-control` 1.0).
  public static let current = ControlProtocolInfo(name: "focus-control", major: 1, minor: 0)

  public var isCompatibleMajor: Bool {
    name == Self.current.name && major == Self.current.major
  }
}

/// Control verbs accepted by the app endpoint.
public enum ControlCommandName: String, Codable, Sendable, Equatable, CaseIterable {
  case status
  case start
  case pause
  case resume
  case skip
  case triggerBreak = "trigger-break"
  case snooze
}

/// Empty arguments object; unknown keys are ignored by Codable.
public struct ControlArguments: Codable, Sendable, Equatable {
  public init() {}
}

/// Client identity carried on every request.
public struct ControlClientInfo: Codable, Sendable, Equatable {
  public var version: String
  public var build: String

  public init(version: String, build: String) {
    self.version = version
    self.build = build
  }

  public static let current = ControlClientInfo(
    version: FocusControlModule.clientVersion,
    build: FocusControlModule.clientBuild
  )
}

/// Versioned request envelope.
public struct ControlRequest: Codable, Sendable, Equatable {
  public var `protocol`: ControlProtocolInfo
  public var requestId: UUID
  public var command: ControlCommandName
  public var arguments: ControlArguments
  public var client: ControlClientInfo

  public init(
    protocol protocolInfo: ControlProtocolInfo = .current,
    requestId: UUID = UUID(),
    command: ControlCommandName,
    arguments: ControlArguments = ControlArguments(),
    client: ControlClientInfo = .current
  ) {
    self.protocol = protocolInfo
    self.requestId = requestId
    self.command = command
    self.arguments = arguments
    self.client = client
  }
}

/// Per-command result summary.
public struct ControlCommandResultDTO: Codable, Sendable, Equatable {
  public var command: ControlCommandName
  public var performed: Bool

  public init(command: ControlCommandName, performed: Bool) {
    self.command = command
    self.performed = performed
  }
}

/// Running-app identity in responses.
public struct ControlAppInfo: Codable, Sendable, Equatable {
  public var running: Bool
  public var version: String?
  public var build: String?
  public var pid: Int32?

  public init(running: Bool, version: String? = nil, build: String? = nil, pid: Int32? = nil) {
    self.running = running
    self.version = version
    self.build = build
    self.pid = pid
  }

  public static let notRunning = ControlAppInfo(running: false)

  public static func running(
    version: String = FocusControlModule.clientVersion,
    build: String = FocusControlModule.clientBuild,
    pid: Int32 = ProcessInfo.processInfo.processIdentifier
  ) -> ControlAppInfo {
    ControlAppInfo(running: true, version: version, build: build, pid: pid)
  }
}

/// Authoritative session projection for JSON responses.
public struct ControlSessionState: Codable, Sendable, Equatable {
  public var phase: String
  public var cycleId: UUID
  public var focusStartedAt: Date?
  public var warningStartsAt: Date?
  public var breakDueAt: Date?
  public var breakEndsAt: Date?
  public var secondsUntilNextTransition: Int?
  public var canPause: Bool
  public var canResume: Bool
  public var canSkip: Bool
  public var canTriggerBreak: Bool
  public var canSnooze: Bool

  public init(
    phase: String,
    cycleId: UUID,
    focusStartedAt: Date? = nil,
    warningStartsAt: Date? = nil,
    breakDueAt: Date? = nil,
    breakEndsAt: Date? = nil,
    secondsUntilNextTransition: Int? = nil,
    canPause: Bool,
    canResume: Bool,
    canSkip: Bool,
    canTriggerBreak: Bool,
    canSnooze: Bool
  ) {
    self.phase = phase
    self.cycleId = cycleId
    self.focusStartedAt = focusStartedAt
    self.warningStartsAt = warningStartsAt
    self.breakDueAt = breakDueAt
    self.breakEndsAt = breakEndsAt
    self.secondsUntilNextTransition = secondsUntilNextTransition
    self.canPause = canPause
    self.canResume = canResume
    self.canSkip = canSkip
    self.canTriggerBreak = canTriggerBreak
    self.canSnooze = canSnooze
  }
}

/// Stable machine-readable error body.
public struct ControlErrorBody: Codable, Sendable, Equatable {
  public var code: String
  public var message: String
  public var retryable: Bool

  public init(code: String, message: String, retryable: Bool) {
    self.code = code
    self.message = message
    self.retryable = retryable
  }

  public static func appNotRunning(
    message: String = "Focus is not running."
  ) -> ControlErrorBody {
    ControlErrorBody(code: "app_not_running", message: message, retryable: true)
  }

  public static func protocolMismatch(
    message: String = "Unsupported focus-control protocol major version."
  ) -> ControlErrorBody {
    ControlErrorBody(code: "protocol_mismatch", message: message, retryable: false)
  }

  public static func rejected(
    message: String = "Command rejected by current state."
  ) -> ControlErrorBody {
    ControlErrorBody(code: "rejected", message: message, retryable: false)
  }

  public static func permissionDenied(
    message: String = "Control endpoint peer check failed."
  ) -> ControlErrorBody {
    ControlErrorBody(code: "permission_denied", message: message, retryable: false)
  }

  public static func timeout(
    message: String = "Timed out waiting for Focus."
  ) -> ControlErrorBody {
    ControlErrorBody(code: "timeout", message: message, retryable: true)
  }

  public static func internalError(
    message: String = "Unexpected control transport failure."
  ) -> ControlErrorBody {
    ControlErrorBody(code: "internal_error", message: message, retryable: false)
  }
}

/// Versioned response envelope.
public struct ControlResponse: Codable, Sendable, Equatable {
  public var `protocol`: ControlProtocolInfo
  public var requestId: UUID
  public var ok: Bool
  public var result: ControlCommandResultDTO?
  public var app: ControlAppInfo
  public var state: ControlSessionState?
  public var error: ControlErrorBody?

  public init(
    protocol protocolInfo: ControlProtocolInfo = .current,
    requestId: UUID,
    ok: Bool,
    result: ControlCommandResultDTO? = nil,
    app: ControlAppInfo,
    state: ControlSessionState? = nil,
    error: ControlErrorBody? = nil
  ) {
    self.protocol = protocolInfo
    self.requestId = requestId
    self.ok = ok
    self.result = result
    self.app = app
    self.state = state
    self.error = error
  }

  public static func success(
    requestId: UUID,
    command: ControlCommandName,
    performed: Bool,
    app: ControlAppInfo,
    state: ControlSessionState,
    protocol protocolInfo: ControlProtocolInfo = .current
  ) -> ControlResponse {
    ControlResponse(
      protocol: protocolInfo,
      requestId: requestId,
      ok: true,
      result: ControlCommandResultDTO(command: command, performed: performed),
      app: app,
      state: state,
      error: nil
    )
  }

  public static func failure(
    requestId: UUID,
    app: ControlAppInfo,
    error: ControlErrorBody,
    state: ControlSessionState? = nil,
    protocol protocolInfo: ControlProtocolInfo = .current
  ) -> ControlResponse {
    ControlResponse(
      protocol: protocolInfo,
      requestId: requestId,
      ok: false,
      result: nil,
      app: app,
      state: state,
      error: error
    )
  }
}

/// Process exit codes from PLAN §8.
public enum ControlExitCode: Int32, Sendable, Equatable {
  case success = 0
  case internalError = 1
  case usageError = 2
  case appNotRunning = 3
  case timeout = 4
  case protocolMismatch = 5
  case rejected = 6
  case permissionFailure = 7

  /// Map a decoded response (and optional transport failure) onto an exit code.
  public static func from(response: ControlResponse) -> ControlExitCode {
    if !response.protocol.isCompatibleMajor {
      return .protocolMismatch
    }
    if response.ok {
      return .success
    }
    switch response.error?.code {
    case "app_not_running":
      return .appNotRunning
    case "protocol_mismatch":
      return .protocolMismatch
    case "rejected", "invalid_for_phase", "use_resume":
      return .rejected
    case "permission_denied":
      return .permissionFailure
    case "timeout":
      return .timeout
    default:
      return .internalError
    }
  }
}
