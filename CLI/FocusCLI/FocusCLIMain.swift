import FocusControl
import FocusSession
import Foundation

@main
enum FocusCLIMain {
  static func main() async {
    let args = Array(CommandLine.arguments.dropFirst())
    let environment = ProcessInfo.processInfo.environment

    let launcher: any AppLauncherClient
    #if DEBUG
      if environment["FOCUS_TEST_LAUNCH_HOOK"] == "1",
        let socket = environment[ControlSocketPath.injectedEnvironmentKey]
      {
        launcher = DebugTestAppLauncher(socketPath: socket)
      } else {
        launcher = UnavailableAppLauncherClient()
      }
    #else
      launcher = UnavailableAppLauncherClient()
    #endif

    let dependencies = FocusCLIRunner.Dependencies(
      pathResolver: DefaultControlSocketPathResolver(environment: environment),
      launcher: launcher
    )
    let code = await FocusCLIRunner.run(arguments: args, dependencies: dependencies)
    exit(code.rawValue)
  }
}

#if DEBUG
  /// DEBUG-only hook: create a minimal listener so Linux CLI cold-start tests can proceed.
  ///
  /// Production Mac builds use Launch Services via a real `AppLauncherClient` in the
  /// app target — never this hook.
  actor DebugTestAppLauncher: AppLauncherClient {
    private let socketPath: String
    private var server: ControlSocketServer?
    private var runtime: SessionRuntime?
    private var ids = IdentifierFactory.deterministic(start: 100)
    private let processor = ControlRequestProcessor()
    private let clock: @Sendable () -> Date

    init(socketPath: String, clock: @escaping @Sendable () -> Date = { Date() }) {
      self.socketPath = socketPath
      self.clock = clock
    }

    func launchFocusApp() async throws {
      if server != nil { return }
      let url = URL(fileURLWithPath: socketPath)
      let parent = url.deletingLastPathComponent()
      try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)

      let server = ControlSocketServer(socketPath: url) { [weak self] request in
        guard let self else {
          return ControlResponse.failure(
            requestId: request.requestId,
            app: .notRunning,
            error: .internalError(message: "Test launcher deallocated.")
          )
        }
        return await self.handle(request)
      }
      try await server.start()
      self.server = server

      let now = clock()
      let reduction = SessionReducer.reduce(
        runtime: nil,
        intent: .start,
        at: now,
        ids: &ids
      )
      runtime = reduction.runtime
    }

    private func handle(_ request: ControlRequest) -> ControlResponse {
      let now = clock()
      let result = processor.process(
        request: request,
        runtime: runtime,
        at: now,
        ids: &ids,
        app: .running(pid: ProcessInfo.processInfo.processIdentifier)
      )
      runtime = result.runtime
      return result.response
    }
  }
#endif
