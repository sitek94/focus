import FocusControl
import FocusSession
import Foundation

/// In-memory Focus control endpoint for Linux CLI integration tests.
actor CLITestFixture {
  private let socketURL: URL
  private var server: ControlSocketServer?
  private var runtime: SessionRuntime?
  private var ids: IdentifierFactory
  private let processor = ControlRequestProcessor()
  private let now: @Sendable () -> Date
  private let appPID: Int32

  init(
    socketURL: URL,
    now: @escaping @Sendable () -> Date = { Date() },
    ids: IdentifierFactory = .deterministic(start: 1),
    appPID: Int32 = ProcessInfo.processInfo.processIdentifier
  ) {
    self.socketURL = socketURL
    self.now = now
    self.ids = ids
    self.appPID = appPID
  }

  var path: URL { socketURL }

  func start(withInitialStart: Bool = true) async throws {
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

    if withInitialStart {
      let reduction = SessionReducer.reduce(
        runtime: nil,
        intent: .start,
        at: now(),
        ids: &ids
      )
      runtime = reduction.runtime
    }
  }

  func stop() async {
    await server?.stop()
    server = nil
  }

  func currentRuntime() -> SessionRuntime? {
    runtime
  }

  private func handle(_ request: ControlRequest) -> ControlResponse {
    let result = processor.process(
      request: request,
      runtime: runtime,
      at: now(),
      ids: &ids,
      app: .running(pid: appPID)
    )
    runtime = result.runtime
    return result.response
  }
}

enum FocusCLIBinary {
  static func url() throws -> URL {
    let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
    let candidates = [
      cwd.appendingPathComponent(".build/debug/focus"),
      cwd.appendingPathComponent(".build/release/focus"),
    ]
    for candidate in candidates where FileManager.default.isExecutableFile(atPath: candidate.path) {
      return candidate
    }
    throw CLIBinaryError.notFound
  }

  struct RunResult: Sendable {
    var exitCode: Int32
    var stdout: String
    var stderr: String
  }

  static func run(
    arguments: [String],
    environment: [String: String]
  ) throws -> RunResult {
    let binary = try url()
    let process = Process()
    process.executableURL = binary
    process.arguments = arguments
    var env = ProcessInfo.processInfo.environment
    for (key, value) in environment {
      env[key] = value
    }
    process.environment = env

    let stdoutPipe = Pipe()
    let stderrPipe = Pipe()
    process.standardOutput = stdoutPipe
    process.standardError = stderrPipe
    try process.run()
    process.waitUntilExit()

    let stdout =
      String(data: stdoutPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)
      ?? ""
    let stderr =
      String(data: stderrPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)
      ?? ""
    return RunResult(exitCode: process.terminationStatus, stdout: stdout, stderr: stderr)
  }
}

enum CLIBinaryError: Error {
  case notFound
}

func makeTempSocketURL() throws -> URL {
  // Keep under Darwin's 104-byte sun_path limit used by ControlSocketPath.
  let parent = URL(
    fileURLWithPath: "/tmp/f\(String(UUID().uuidString.prefix(8)))", isDirectory: true)
  try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
  let url = parent.appendingPathComponent(ControlSocketPath.fileName)
  try ControlSocketPath.validatePathLength(url.path)
  return url
}
