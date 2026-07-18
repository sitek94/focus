import Foundation

/// High-level CLI command session: resolve path, optional cold-launch, send, map exits.
public struct ControlCLISession: Sendable {
  public var pathResolver: any ControlSocketPathResolving
  public var timeouts: ControlTimeouts
  public var peerChecker: any ControlPeerIdentityChecking
  public var launcher: any AppLauncherClient
  public var makeRequestId: @Sendable () -> UUID

  public init(
    pathResolver: any ControlSocketPathResolving,
    timeouts: ControlTimeouts = .default,
    peerChecker: any ControlPeerIdentityChecking = ControlPeerIdentity.makeDefaultChecker(),
    launcher: any AppLauncherClient = UnavailableAppLauncherClient(),
    makeRequestId: @escaping @Sendable () -> UUID = { UUID() }
  ) {
    self.pathResolver = pathResolver
    self.timeouts = timeouts
    self.peerChecker = peerChecker
    self.launcher = launcher
    self.makeRequestId = makeRequestId
  }

  public struct Outcome: Sendable {
    public var response: ControlResponse?
    public var exitCode: ControlExitCode
    public var transportError: ControlTransportError?

    public init(
      response: ControlResponse?,
      exitCode: ControlExitCode,
      transportError: ControlTransportError? = nil
    ) {
      self.response = response
      self.exitCode = exitCode
      self.transportError = transportError
    }
  }

  /// Run `command`. Only `start` may cold-launch via `launcher`.
  public func run(command: ControlCommandName) async -> Outcome {
    let request = ControlRequest(
      requestId: makeRequestId(),
      command: command
    )

    let socketURL: URL
    do {
      socketURL = try pathResolver.resolveSocketURL()
    } catch let pathError as ControlSocketPathError {
      if command == .start {
        return await coldStart(request: request, pathError: pathError)
      }
      return Outcome(
        response: nil,
        exitCode: .appNotRunning,
        transportError: .path(pathError)
      )
    } catch {
      return Outcome(
        response: nil,
        exitCode: .internalError,
        transportError: .socket(String(describing: error))
      )
    }

    do {
      let response = try await send(request, socketURL: socketURL)
      return Outcome(response: response, exitCode: ControlExitCode.from(response: response))
    } catch let transport as ControlTransportError {
      if command == .start,
        transport == .appNotRunning || transport == .connectTimeout
      {
        return await coldStart(request: request, existingURL: socketURL)
      }
      return Outcome(
        response: nil,
        exitCode: ControlExitCode.from(transport: transport),
        transportError: transport
      )
    } catch {
      return Outcome(
        response: nil,
        exitCode: .internalError,
        transportError: .socket(String(describing: error))
      )
    }
  }

  private func coldStart(
    request: ControlRequest,
    pathError: ControlSocketPathError? = nil,
    existingURL: URL? = nil
  ) async -> Outcome {
    do {
      try await launcher.launchFocusApp()
    } catch let transport as ControlTransportError {
      return Outcome(
        response: nil,
        exitCode: ControlExitCode.from(transport: transport),
        transportError: transport
      )
    } catch {
      return Outcome(
        response: nil,
        exitCode: .appNotRunning,
        transportError: .appNotRunning
      )
    }

    let deadline = ContinuousClock.now + timeouts.coldStart
    var lastError: ControlTransportError =
      pathError.map(ControlTransportError.path) ?? .appNotRunning

    while ContinuousClock.now < deadline {
      if Task.isCancelled {
        return Outcome(response: nil, exitCode: .internalError, transportError: .cancelled)
      }
      let url: URL
      if let existingURL {
        url = existingURL
      } else {
        do {
          url = try pathResolver.resolveSocketURL()
        } catch let path as ControlSocketPathError {
          lastError = .path(path)
          try? await Task.sleep(for: .milliseconds(50))
          continue
        } catch {
          lastError = .socket(String(describing: error))
          try? await Task.sleep(for: .milliseconds(50))
          continue
        }
      }

      do {
        let response = try await send(request, socketURL: url)
        return Outcome(response: response, exitCode: ControlExitCode.from(response: response))
      } catch let transport as ControlTransportError {
        lastError = transport
        try? await Task.sleep(for: .milliseconds(50))
      } catch {
        lastError = .socket(String(describing: error))
        try? await Task.sleep(for: .milliseconds(50))
      }
    }

    if lastError == .connectTimeout || lastError == .commandTimeout {
      return Outcome(response: nil, exitCode: .timeout, transportError: lastError)
    }
    return Outcome(response: nil, exitCode: .timeout, transportError: .connectTimeout)
  }

  private func send(_ request: ControlRequest, socketURL: URL) async throws -> ControlResponse {
    let client = ControlSocketClient(
      socketPath: socketURL,
      timeouts: timeouts,
      peerChecker: peerChecker
    )
    return try await client.send(request)
  }
}
