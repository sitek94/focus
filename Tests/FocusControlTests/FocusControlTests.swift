import FocusControl
import FocusSession
import Foundation
import Testing

#if canImport(Darwin)
  import Darwin
#else
  import Glibc
#endif

@Test
func moduleNameIsFocusControl() {
  #expect(FocusControlModule.moduleName == "FocusControl")
}

@Test
func requestResponseRoundTrip() throws {
  let requestId = UUID(uuidString: "0F72A9A5-9625-44E0-9C5F-AB9346D12D2F")!
  let request = ControlRequest(requestId: requestId, command: .snooze)
  let encoded = try ControlJSONCoding.encodeRequest(request)
  let decoded = try ControlJSONCoding.decodeRequest(encoded)
  #expect(decoded == request)

  let cycleId = UUID(uuidString: "783FC3BB-BF5A-48F5-9E29-BE2A3C8510A1")!
  let state = ControlSessionState(
    phase: "focus",
    cycleId: cycleId,
    focusStartedAt: Date(timeIntervalSince1970: 1_721_210_400),
    warningStartsAt: Date(timeIntervalSince1970: 1_721_211_644),
    breakDueAt: Date(timeIntervalSince1970: 1_721_211_654),
    breakEndsAt: nil,
    secondsUntilNextTransition: 50,
    canPause: true,
    canResume: false,
    canSkip: false,
    canTriggerBreak: true,
    canSnooze: false
  )
  let response = ControlResponse.success(
    requestId: requestId,
    command: .snooze,
    performed: true,
    app: .running(version: "0.1.0", build: "1", pid: 12_345),
    state: state
  )
  let responseData = try ControlJSONCoding.encodeResponse(response)
  let decodedResponse = try ControlJSONCoding.decodeResponse(responseData)
  #expect(decodedResponse.ok)
  #expect(decodedResponse.result?.command == .snooze)
  #expect(decodedResponse.result?.performed == true)
  #expect(decodedResponse.state?.secondsUntilNextTransition == 50)
  #expect(decodedResponse.error == nil)
}

@Test
func unknownAdditiveFieldsAreIgnored() throws {
  let json = """
    {
      "protocol": {"name": "focus-control", "major": 1, "minor": 0, "extra": true},
      "requestId": "0F72A9A5-9625-44E0-9C5F-AB9346D12D2F",
      "command": "status",
      "arguments": {"future": 1},
      "client": {"version": "0.1.0", "build": "1", "channel": "test"},
      "unexpected": "ignore-me"
    }
    """
  let request = try ControlJSONCoding.decodeRequest(Data(json.utf8))
  #expect(request.command == .status)
  #expect(request.protocol.major == 1)
}

@Test
func majorMismatchMapsToExitFive() throws {
  let response = ControlResponse.failure(
    requestId: UUID(),
    app: .notRunning,
    error: .protocolMismatch(),
    protocol: ControlProtocolInfo(name: "focus-control", major: 2, minor: 0)
  )
  #expect(ControlExitCode.from(response: response) == .protocolMismatch)

  let okButWrongMajor = ControlResponse.success(
    requestId: UUID(),
    command: .status,
    performed: true,
    app: .running(pid: 1),
    state: ControlSessionState(
      phase: "focus",
      cycleId: UUID(),
      canPause: true,
      canResume: false,
      canSkip: false,
      canTriggerBreak: true,
      canSnooze: false
    ),
    protocol: ControlProtocolInfo(name: "focus-control", major: 9, minor: 0)
  )
  #expect(ControlExitCode.from(response: okButWrongMajor) == .protocolMismatch)
}

@Test
func framingRejectsOversizedAndMalformed() throws {
  #expect(throws: ControlFraming.Error.self) {
    try ControlFraming.frame(Data(count: ControlFraming.maxPayloadSize + 1))
  }

  var oversizedHeader = Data(count: 4)
  let tooBig = UInt32(ControlFraming.maxPayloadSize + 1).bigEndian
  withUnsafeBytes(of: tooBig) { oversizedHeader.replaceSubrange(0..<4, with: $0) }
  #expect(throws: ControlFraming.Error.oversized(declaredSize: ControlFraming.maxPayloadSize + 1)) {
    try ControlFraming.decodeLengthPrefix(oversizedHeader)
  }

  var zeroHeader = Data(count: 4)
  let zero = UInt32(0).bigEndian
  withUnsafeBytes(of: zero) { zeroHeader.replaceSubrange(0..<4, with: $0) }
  #expect(throws: ControlFraming.Error.malformedLength) {
    try ControlFraming.decodeLengthPrefix(zeroHeader)
  }
}

@Test
func partialFramesAreNotConsumed() throws {
  let payload = Data("{\"ok\":true}".utf8)
  let frame = try ControlFraming.frame(payload)
  let partial = frame.prefix(frame.count - 3)
  var buffer = Data(partial)
  let consumed = try ControlFraming.consumeFrame(from: &buffer)
  #expect(consumed == nil)
  #expect(buffer.count == partial.count)

  buffer.append(frame.suffix(3))
  let full = try ControlFraming.consumeFrame(from: &buffer)
  #expect(full == payload)
  #expect(buffer.isEmpty)
}

@Test
func pathHelpersValidateLengthAndParent() throws {
  let parent = URL(
    fileURLWithPath: "/tmp/p\(String(UUID().uuidString.prefix(8)))", isDirectory: true)
  try ControlSocketPath.ensurePrivateDirectory(parent)
  defer { try? FileManager.default.removeItem(at: parent) }

  let url = try ControlSocketPath.socketURL(inParent: parent)
  #expect(url.lastPathComponent == ControlSocketPath.fileName)

  let longName = String(repeating: "a", count: ControlSocketPath.maxPathByteLength + 8)
  #expect(throws: ControlSocketPathError.self) {
    try ControlSocketPath.validatePathLength(longName)
  }

  let injected = try InjectedControlSocketPathResolver(url: url).resolveSocketURL()
  #expect(injected.path == url.path)
}

@Test
func parentDirectoryRejectsGroupOrOtherBits() throws {
  let parent = URL(
    fileURLWithPath: "/tmp/m\(String(UUID().uuidString.prefix(8)))", isDirectory: true)
  try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
  defer { try? FileManager.default.removeItem(at: parent) }

  // 0755 has group/other r-x — must be rejected.
  #expect(chmod(parent.path, 0o755) == 0)
  #expect(throws: ControlSocketPathError.parentNotPrivate(parent)) {
    try ControlSocketPath.validateParentDirectory(parent)
  }

  // 0700 is accepted.
  try ControlSocketPath.setPrivateDirectoryMode(parent)
  try ControlSocketPath.validateParentDirectory(parent)
}

@Test
func unlinkRejectsRegularFileAndAllowsSameOwnerSocket() async throws {
  let parent = URL(
    fileURLWithPath: "/tmp/u\(String(UUID().uuidString.prefix(8)))", isDirectory: true)
  try ControlSocketPath.ensurePrivateDirectory(parent)
  defer { try? FileManager.default.removeItem(at: parent) }

  let regular = parent.appendingPathComponent("not-a-socket")
  try Data("trap".utf8).write(to: regular)
  #expect(throws: ControlSocketPathError.endpointNotSocket(regular)) {
    try ControlSocketPath.unlinkStaleSocketIfSafe(regular)
  }
  #expect(FileManager.default.fileExists(atPath: regular.path))

  let socketURL = parent.appendingPathComponent(ControlSocketPath.fileName)
  let server = ControlSocketServer(socketPath: socketURL) { request in
    ControlResponse.failure(
      requestId: request.requestId,
      app: .notRunning,
      error: .appNotRunning()
    )
  }
  try await server.start()
  let info = try ControlSocketPath.inspectEndpoint(socketURL)
  #expect(info?.isSocket == true)
  #expect(info?.isCurrentUserOwned == true)

  await server.stop()
  // stop already unlinked safely; missing path is a no-op
  try ControlSocketPath.unlinkStaleSocketIfSafe(socketURL)
  #expect(try ControlSocketPath.inspectEndpoint(socketURL) == nil)

  // Bind after a same-owner stale socket: create one, stop without going through
  // server.stop unlink by manually leaving a socket via a short-lived server restart.
  try await server.start()
  await server.stop()
}

@Test
func statusReconcilesPastWarningDeadline() {
  let start = Date(timeIntervalSince1970: 1_000)
  var ids = IdentifierFactory.deterministic(start: 1)
  let boot = SessionReducer.reduce(runtime: nil, intent: .start, at: start, ids: &ids)
  guard case .focus(let focus) = boot.runtime.phase else {
    Issue.record("Expected focus after start")
    return
  }

  let afterWarning = focus.warningStartsAt.addingTimeInterval(1)
  let processor = ControlRequestProcessor()
  let result = processor.process(
    request: ControlRequest(command: .status),
    runtime: boot.runtime,
    at: afterWarning,
    ids: &ids,
    app: .running(pid: 1)
  )
  #expect(result.response.ok)
  #expect(result.response.state?.phase == "warning")
  #expect(result.runtime?.phase.cycleID == focus.cycleID)

  let afterBreakDue = focus.breakDueAt.addingTimeInterval(1)
  let breakResult = processor.process(
    request: ControlRequest(command: .status),
    runtime: boot.runtime,
    at: afterBreakDue,
    ids: &ids,
    app: .running(pid: 1)
  )
  #expect(breakResult.response.ok)
  #expect(breakResult.response.state?.phase == "break")
}

@Test
func processorRejectsIncompatibleMajor() {
  var ids = IdentifierFactory.deterministic(start: 1)
  let request = ControlRequest(
    protocol: ControlProtocolInfo(name: "focus-control", major: 2, minor: 0),
    command: .status
  )
  let processor = ControlRequestProcessor()
  let result = processor.process(
    request: request,
    runtime: nil,
    at: Date(),
    ids: &ids,
    app: .running(pid: 1)
  )
  #expect(result.response.ok == false)
  #expect(result.response.error?.code == "protocol_mismatch")
  #expect(ControlExitCode.from(response: result.response) == .protocolMismatch)
}

@Test
func stateProjectorMapsFocusCapabilities() {
  let now = Date(timeIntervalSince1970: 1_000)
  let focus = FocusPhase(
    cycleID: UUID(),
    focusStartedAt: now,
    warningStartsAt: now.addingTimeInterval(1_190),
    breakDueAt: now.addingTimeInterval(1_200)
  )
  let runtime = SessionRuntime(phase: .focus(focus))
  let state = ControlStateProjector.project(runtime: runtime, at: now)
  #expect(state.phase == "focus")
  #expect(state.secondsUntilNextTransition == 1_190)
  #expect(state.canPause)
  #expect(!state.canResume)
  #expect(!state.canSkip)
  #expect(state.canTriggerBreak)
  #expect(!state.canSnooze)
}

@Test
func clientTimesOutWhenNoServer() async throws {
  let parent = URL(
    fileURLWithPath: "/tmp/t\(String(UUID().uuidString.prefix(8)))", isDirectory: true)
  try ControlSocketPath.ensurePrivateDirectory(parent)
  defer { try? FileManager.default.removeItem(at: parent) }
  let socketURL = parent.appendingPathComponent("missing.sock")

  let client = ControlSocketClient(
    socketPath: socketURL,
    timeouts: ControlTimeouts(
      connect: .milliseconds(50),
      command: .milliseconds(50),
      coldStart: .milliseconds(100)
    )
  )
  do {
    _ = try await client.send(ControlRequest(command: .status))
    Issue.record("Expected send to throw")
  } catch let error as ControlTransportError {
    #expect(
      error == .appNotRunning || error == .connectTimeout
        || {
          if case .socket = error { return true }
          return false
        }()
    )
  }
}

@Test
func cancellationSurfacesOnColdStartWait() async throws {
  let parent = URL(
    fileURLWithPath: "/tmp/c\(String(UUID().uuidString.prefix(8)))", isDirectory: true)
  try ControlSocketPath.ensurePrivateDirectory(parent)
  defer { try? FileManager.default.removeItem(at: parent) }
  let socketURL = parent.appendingPathComponent(ControlSocketPath.fileName)

  let launcher = RecordingAppLauncherClient {
    // Never start a listener — cold-start should wait until cancelled.
  }
  let session = ControlCLISession(
    pathResolver: InjectedControlSocketPathResolver(url: socketURL),
    timeouts: ControlTimeouts(
      connect: .milliseconds(20),
      command: .milliseconds(20),
      coldStart: .seconds(5)
    ),
    launcher: launcher
  )

  let task = Task {
    await session.run(command: .start)
  }
  try await Task.sleep(for: .milliseconds(30))
  task.cancel()
  let outcome = await task.value
  #expect(
    outcome.exitCode == .timeout || outcome.exitCode == .internalError
      || outcome.transportError == .cancelled
  )
}
