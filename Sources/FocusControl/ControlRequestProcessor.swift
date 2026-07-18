import FocusSession
import Foundation

/// Applies a control request against an optional runtime (app owner / test fixture).
public struct ControlRequestProcessor: Sendable {
  public init() {}

  public struct ProcessResult: Sendable {
    public var response: ControlResponse
    public var runtime: SessionRuntime?
    public var events: [OutcomeEvent]

    public init(
      response: ControlResponse,
      runtime: SessionRuntime?,
      events: [OutcomeEvent] = []
    ) {
      self.response = response
      self.runtime = runtime
      self.events = events
    }
  }

  public func process(
    request: ControlRequest,
    runtime: SessionRuntime?,
    at now: Date,
    ids: inout IdentifierFactory,
    app: ControlAppInfo
  ) -> ProcessResult {
    guard request.protocol.isCompatibleMajor else {
      return ProcessResult(
        response: ControlResponse.failure(
          requestId: request.requestId,
          app: app,
          error: .protocolMismatch(),
          protocol: ControlProtocolInfo.current
        ),
        runtime: runtime
      )
    }

    switch request.command {
    case .status:
      guard let runtime else {
        return ProcessResult(
          response: ControlResponse.failure(
            requestId: request.requestId,
            app: app,
            error: .appNotRunning()
          ),
          runtime: nil
        )
      }
      let state = ControlStateProjector.project(runtime: runtime, at: now)
      return ProcessResult(
        response: ControlResponse.success(
          requestId: request.requestId,
          command: .status,
          performed: true,
          app: app,
          state: state
        ),
        runtime: runtime
      )

    case .start, .pause, .resume, .skip, .triggerBreak, .snooze:
      let intent = intent(for: request.command)
      let reduction = SessionReducer.reduce(
        runtime: runtime,
        intent: intent,
        at: now,
        ids: &ids
      )
      switch reduction.commandResult {
      case .performed, .noop:
        let performed = reduction.commandResult == .performed
        let state = ControlStateProjector.project(runtime: reduction.runtime, at: now)
        return ProcessResult(
          response: ControlResponse.success(
            requestId: request.requestId,
            command: request.command,
            performed: performed,
            app: app,
            state: state
          ),
          runtime: reduction.runtime,
          events: reduction.events
        )

      case .rejected(let rejection):
        let message: String
        let code: String
        switch rejection {
        case .useResume:
          message = "Session is paused; use resume."
          code = "use_resume"
        case .invalidForPhase:
          message = "Command rejected by current state."
          code = "rejected"
        }
        let state = ControlStateProjector.project(runtime: reduction.runtime, at: now)
        return ProcessResult(
          response: ControlResponse.failure(
            requestId: request.requestId,
            app: app,
            error: ControlErrorBody(code: code, message: message, retryable: false),
            state: state
          ),
          runtime: reduction.runtime,
          events: reduction.events
        )
      }
    }
  }

  private func intent(for command: ControlCommandName) -> SessionIntent {
    switch command {
    case .status:
      return .reconcile
    case .start:
      return .start
    case .pause:
      return .pause
    case .resume:
      return .resume
    case .skip:
      return .skip(source: .cli)
    case .triggerBreak:
      return .triggerBreak
    case .snooze:
      return .snooze(source: .cli)
    }
  }
}
