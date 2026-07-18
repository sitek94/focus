import FocusControl
import Foundation

/// Programmatic CLI entry used by `@main`.
enum FocusCLIRunner {
  struct Dependencies: Sendable {
    var pathResolver: any ControlSocketPathResolving
    var timeouts: ControlTimeouts
    var peerChecker: any ControlPeerIdentityChecking
    var launcher: any AppLauncherClient
    var makeRequestId: @Sendable () -> UUID
    var stdout: @Sendable (String) -> Void
    var stderr: @Sendable (String) -> Void

    init(
      pathResolver: any ControlSocketPathResolving = DefaultControlSocketPathResolver(),
      timeouts: ControlTimeouts = .default,
      peerChecker: any ControlPeerIdentityChecking = ControlPeerIdentity.makeDefaultChecker(),
      launcher: any AppLauncherClient = UnavailableAppLauncherClient(),
      makeRequestId: @escaping @Sendable () -> UUID = { UUID() },
      stdout: @escaping @Sendable (String) -> Void = { print($0) },
      stderr: @escaping @Sendable (String) -> Void = { message in
        if let data = (message + "\n").data(using: .utf8) {
          FileHandle.standardError.write(data)
        }
      }
    ) {
      self.pathResolver = pathResolver
      self.timeouts = timeouts
      self.peerChecker = peerChecker
      self.launcher = launcher
      self.makeRequestId = makeRequestId
      self.stdout = stdout
      self.stderr = stderr
    }
  }

  @discardableResult
  static func run(
    arguments: [String],
    dependencies: Dependencies = Dependencies()
  ) async -> ControlExitCode {
    switch CLIArguments.parse(arguments) {
    case .failure(let error):
      dependencies.stderr(error.message)
      dependencies.stderr("Try: focus --help")
      return .usageError

    case .success(let parsed):
      if parsed.help {
        dependencies.stdout(CLIHelp.text)
        return .success
      }
      if parsed.version {
        dependencies.stdout("focus \(FocusControlModule.clientVersion)")
        return .success
      }
      guard let command = parsed.command else {
        dependencies.stderr("Missing command.")
        return .usageError
      }
      return await execute(command: command, json: parsed.json, dependencies: dependencies)
    }
  }

  private static func execute(
    command: ControlCommandName,
    json: Bool,
    dependencies: Dependencies
  ) async -> ControlExitCode {
    let session = ControlCLISession(
      pathResolver: dependencies.pathResolver,
      timeouts: dependencies.timeouts,
      peerChecker: dependencies.peerChecker,
      launcher: dependencies.launcher,
      makeRequestId: dependencies.makeRequestId
    )
    let outcome = await session.run(command: command)

    if json {
      if let response = outcome.response {
        if let data = try? ControlJSONCoding.encodeResponse(response),
          let text = String(data: data, encoding: .utf8)
        {
          dependencies.stdout(text)
        } else {
          dependencies.stderr("Failed to encode JSON response.")
          return .internalError
        }
      } else if let transport = outcome.transportError {
        let synthetic = ControlResponse.failure(
          requestId: dependencies.makeRequestId(),
          app: .notRunning,
          error: errorBody(for: transport)
        )
        if let data = try? ControlJSONCoding.encodeResponse(synthetic),
          let text = String(data: data, encoding: .utf8)
        {
          dependencies.stdout(text)
        }
      }
      return outcome.exitCode
    }

    if outcome.exitCode == .success, let response = outcome.response {
      dependencies.stdout(HumanOutput.successLine(command: command, response: response))
      return .success
    }

    let line = HumanOutput.errorLine(
      exitCode: outcome.exitCode,
      response: outcome.response,
      transport: outcome.transportError
    )
    if !line.isEmpty {
      dependencies.stderr(line)
    }
    return outcome.exitCode
  }

  private static func errorBody(for transport: ControlTransportError) -> ControlErrorBody {
    switch transport {
    case .appNotRunning, .path:
      return .appNotRunning()
    case .connectTimeout, .commandTimeout:
      return .timeout()
    case .protocolMismatch:
      return .protocolMismatch()
    case .permissionFailure:
      return .permissionDenied()
    case .cancelled, .framing, .decoding, .encoding, .socket:
      return .internalError()
    }
  }
}
