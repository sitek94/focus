import FocusControl
import FocusSession
import Foundation
import Testing

@Suite(.serialized)
struct FocusCLIIntegrationSuite {
  @Test
  func statusWithoutServerExitsThree() throws {
    let socket = try makeTempSocketURL()
    defer { try? FileManager.default.removeItem(at: socket.deletingLastPathComponent()) }

    let result = try FocusCLIBinary.run(
      arguments: ["status"],
      environment: [ControlSocketPath.injectedEnvironmentKey: socket.path]
    )
    #expect(result.exitCode == ControlExitCode.appNotRunning.rawValue)
    #expect(result.stderr.contains("Focus is not running."))
  }

  @Test
  func allSevenCommandsHumanAndJSON() async throws {
    let socket = try makeTempSocketURL()
    defer { try? FileManager.default.removeItem(at: socket.deletingLastPathComponent()) }

    let fixedNow = Date(timeIntervalSince1970: 1_721_210_400)
    let fixture = CLITestFixture(socketURL: socket, now: { fixedNow })
    try await fixture.start()

    let env = [ControlSocketPath.injectedEnvironmentKey: socket.path]

    let status = try FocusCLIBinary.run(arguments: ["status"], environment: env)
    #expect(status.exitCode == 0)
    #expect(status.stdout.contains("Focus is running: focus,"))
    #expect(status.stdout.contains("until warning"))

    let statusJSON = try FocusCLIBinary.run(arguments: ["status", "--json"], environment: env)
    #expect(statusJSON.exitCode == 0)
    let statusResponse = try ControlJSONCoding.decodeResponse(Data(statusJSON.stdout.utf8))
    #expect(statusResponse.ok)
    #expect(statusResponse.state?.phase == "focus")
    #expect(statusResponse.protocol.major == 1)

    let start = try FocusCLIBinary.run(arguments: ["start"], environment: env)
    #expect(start.exitCode == 0)
    #expect(start.stdout.contains("Focus is active:"))

    let pause = try FocusCLIBinary.run(arguments: ["pause"], environment: env)
    #expect(pause.exitCode == 0)
    #expect(pause.stdout.contains("Paused"))

    let resume = try FocusCLIBinary.run(arguments: ["resume"], environment: env)
    #expect(resume.exitCode == 0)
    #expect(
      resume.stdout.contains("Focus resumed:") || resume.stdout.contains("Focus is already active:")
    )

    let resumeAgain = try FocusCLIBinary.run(arguments: ["resume"], environment: env)
    #expect(resumeAgain.exitCode == 0)
    #expect(resumeAgain.stdout.contains("Focus is already active:"))

    let trigger = try FocusCLIBinary.run(arguments: ["trigger-break"], environment: env)
    #expect(trigger.exitCode == 0)
    #expect(trigger.stdout.contains("Break started."))

    let skip = try FocusCLIBinary.run(arguments: ["skip"], environment: env)
    #expect(skip.exitCode == 0)
    #expect(skip.stdout.contains("Break skipped."))

    let snoozeRejected = try FocusCLIBinary.run(arguments: ["snooze"], environment: env)
    #expect(snoozeRejected.exitCode == ControlExitCode.rejected.rawValue)

    await fixture.stop()

    let warningSocket = try makeTempSocketURL()
    defer { try? FileManager.default.removeItem(at: warningSocket.deletingLastPathComponent()) }
    let warningNow = fixedNow.addingTimeInterval(FocusPolicy.focusUntilWarning)
    var ids = IdentifierFactory.deterministic(start: 50)
    let boot = SessionReducer.reduce(runtime: nil, intent: .start, at: fixedNow, ids: &ids)
    let atWarning = SessionReducer.reduce(
      runtime: boot.runtime,
      intent: .reconcile,
      at: warningNow,
      ids: &ids
    )
    guard case .warning = atWarning.runtime.phase else {
      Issue.record("Expected warning phase for snooze coverage")
      return
    }

    let seeded = WarningSeededFixture(
      socketURL: warningSocket,
      runtime: atWarning.runtime,
      ids: ids,
      now: warningNow
    )
    try await seeded.start()

    let warnEnv = [ControlSocketPath.injectedEnvironmentKey: warningSocket.path]
    let snooze = try FocusCLIBinary.run(arguments: ["snooze"], environment: warnEnv)
    #expect(snooze.exitCode == 0)
    #expect(snooze.stdout.contains("Break snoozed for 1m."))

    let readBack = try FocusCLIBinary.run(arguments: ["status", "--json"], environment: warnEnv)
    #expect(readBack.exitCode == 0)
    let afterSnooze = try ControlJSONCoding.decodeResponse(Data(readBack.stdout.utf8))
    #expect(afterSnooze.state?.phase == "focus")
    #expect(afterSnooze.state?.canSnooze == false)

    await seeded.stop()
  }

  @Test
  func skipDuringFocusRejected() async throws {
    let socket = try makeTempSocketURL()
    defer { try? FileManager.default.removeItem(at: socket.deletingLastPathComponent()) }
    let fixture = CLITestFixture(socketURL: socket)
    try await fixture.start()

    let result = try FocusCLIBinary.run(
      arguments: ["skip", "--json"],
      environment: [ControlSocketPath.injectedEnvironmentKey: socket.path]
    )
    #expect(result.exitCode == ControlExitCode.rejected.rawValue)
    let response = try ControlJSONCoding.decodeResponse(Data(result.stdout.utf8))
    #expect(response.ok == false)
    #expect(response.error?.code == "rejected")

    await fixture.stop()
  }

  @Test
  func usageErrorExitTwo() throws {
    let result = try FocusCLIBinary.run(arguments: ["nope"], environment: [:])
    #expect(result.exitCode == ControlExitCode.usageError.rawValue)
    #expect(result.stderr.contains("Unknown argument"))
  }

  @Test
  func versionFlag() throws {
    let result = try FocusCLIBinary.run(arguments: ["--version"], environment: [:])
    #expect(result.exitCode == 0)
    #expect(result.stdout.contains("focus \(FocusControlModule.clientVersion)"))
  }

  @Test
  func postCommandReadBackMatches() async throws {
    let socket = try makeTempSocketURL()
    defer { try? FileManager.default.removeItem(at: socket.deletingLastPathComponent()) }
    let fixture = CLITestFixture(socketURL: socket)
    try await fixture.start()

    let env = [ControlSocketPath.injectedEnvironmentKey: socket.path]
    let pause = try FocusCLIBinary.run(arguments: ["pause", "--json"], environment: env)
    let pauseResponse = try ControlJSONCoding.decodeResponse(Data(pause.stdout.utf8))
    #expect(pauseResponse.state?.phase == "paused")

    let status = try FocusCLIBinary.run(arguments: ["status", "--json"], environment: env)
    let statusResponse = try ControlJSONCoding.decodeResponse(Data(status.stdout.utf8))
    #expect(statusResponse.state?.phase == "paused")
    #expect(statusResponse.state?.cycleId == pauseResponse.state?.cycleId)
    #expect(statusResponse.state?.canResume == true)

    await fixture.stop()
  }

  @Test
  func concurrentCommandsSerialize() async throws {
    let socket = try makeTempSocketURL()
    defer { try? FileManager.default.removeItem(at: socket.deletingLastPathComponent()) }
    let fixture = CLITestFixture(socketURL: socket)
    try await fixture.start()

    let env = [ControlSocketPath.injectedEnvironmentKey: socket.path]
    async let a = FocusCLIBinary.run(arguments: ["status", "--json"], environment: env)
    async let b = FocusCLIBinary.run(arguments: ["status", "--json"], environment: env)
    async let c = FocusCLIBinary.run(arguments: ["pause", "--json"], environment: env)
    let results = try await [a, b, c]
    #expect(results.allSatisfy { $0.exitCode == 0 })

    let status = try FocusCLIBinary.run(arguments: ["status", "--json"], environment: env)
    let response = try ControlJSONCoding.decodeResponse(Data(status.stdout.utf8))
    #expect(response.state?.phase == "paused")

    await fixture.stop()
  }

  @Test
  func appLauncherClientInjectionColdStarts() async throws {
    let socket = try makeTempSocketURL()
    defer { try? FileManager.default.removeItem(at: socket.deletingLastPathComponent()) }

    let fixture = CLITestFixture(socketURL: socket)
    let launcher = RecordingAppLauncherClient {
      try await fixture.start()
    }

    let session = ControlCLISession(
      pathResolver: InjectedControlSocketPathResolver(url: socket),
      timeouts: ControlTimeouts(
        connect: .milliseconds(100),
        command: .milliseconds(500),
        coldStart: .seconds(2)
      ),
      launcher: launcher
    )

    let statusOutcome = await session.run(command: .status)
    #expect(statusOutcome.exitCode == .appNotRunning)
    #expect(await launcher.launchCount == 0)

    let startOutcome = await session.run(command: .start)
    #expect(startOutcome.exitCode == .success)
    #expect(await launcher.launchCount == 1)
    #expect(startOutcome.response?.state?.phase == "focus")

    await fixture.stop()
  }

  @Test
  func subprocessColdStartViaDebugHook() throws {
    let socket = try makeTempSocketURL()
    defer { try? FileManager.default.removeItem(at: socket.deletingLastPathComponent()) }

    let result = try FocusCLIBinary.run(
      arguments: ["start", "--json"],
      environment: [
        ControlSocketPath.injectedEnvironmentKey: socket.path,
        "FOCUS_TEST_LAUNCH_HOOK": "1",
      ]
    )
    #expect(result.exitCode == 0)
    let response = try ControlJSONCoding.decodeResponse(Data(result.stdout.utf8))
    #expect(response.ok)
    #expect(response.state?.phase == "focus")
  }
}  // FocusCLIIntegrationSuite

// MARK: - Warning-seeded fixture

actor WarningSeededFixture {
  private let socketURL: URL
  private var server: ControlSocketServer?
  private var runtime: SessionRuntime
  private var ids: IdentifierFactory
  private let processor = ControlRequestProcessor()
  private let now: Date

  init(socketURL: URL, runtime: SessionRuntime, ids: IdentifierFactory, now: Date) {
    self.socketURL = socketURL
    self.runtime = runtime
    self.ids = ids
    self.now = now
  }

  func start() async throws {
    let parent = socketURL.deletingLastPathComponent()
    try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
    let server = ControlSocketServer(socketPath: socketURL) { [weak self] request in
      guard let self else {
        return ControlResponse.failure(
          requestId: request.requestId,
          app: .notRunning,
          error: .internalError()
        )
      }
      return await self.handle(request)
    }
    try await server.start()
    self.server = server
  }

  func stop() async {
    await server?.stop()
  }

  private func handle(_ request: ControlRequest) -> ControlResponse {
    let result = processor.process(
      request: request,
      runtime: runtime,
      at: now,
      ids: &ids,
      app: .running(pid: ProcessInfo.processInfo.processIdentifier)
    )
    runtime = result.runtime ?? runtime
    return result.response
  }
}
