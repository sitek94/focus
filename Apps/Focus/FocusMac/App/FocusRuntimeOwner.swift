import FocusControl
import FocusPersistence
import FocusSession
import Foundation
import Observation

/// Sole `@MainActor` authority for the current session and presentation directives.
@MainActor
@Observable
final class FocusRuntimeOwner {
  private(set) var runtime: SessionRuntime?
  private(set) var presentation: PresentationDirective = .none
  private(set) var lastCommandResult: SessionCommandResult = .performed
  private(set) var isBootstrapped = false

  private var ids: IdentifierFactory
  private let clock: any WallClock
  private let store: FocusEventStore
  private let wakeScheduler: WakeScheduler
  private let processor = ControlRequestProcessor()
  private let overlayCoordinator: OverlaySessionCoordinator
  private let warningCoordinator: WarningPanelCoordinator
  private var wakeLoopTask: Task<Void, Never>?
  private var controlServer: ControlSocketServer?
  private var controlMailbox: ControlMailbox?
  private var isApplyingPresentation = false

  let launchAtLogin: LaunchAtLoginClient
  let updatePreferences: UpdatePreferencesClient
  let cliInstaller: CLIInstaller

  init(
    store: FocusEventStore,
    clock: any WallClock = SystemWallClock(),
    ids: IdentifierFactory = .random,
    wakeScheduler: WakeScheduler = WakeScheduler(),
    overlayCoordinator: OverlaySessionCoordinator = OverlaySessionCoordinator(),
    warningCoordinator: WarningPanelCoordinator = WarningPanelCoordinator(),
    launchAtLogin: LaunchAtLoginClient = LaunchAtLoginClient(),
    updatePreferences: UpdatePreferencesClient = UpdatePreferencesClient(),
    cliInstaller: CLIInstaller = CLIInstaller()
  ) {
    self.store = store
    self.clock = clock
    self.ids = ids
    self.wakeScheduler = wakeScheduler
    self.overlayCoordinator = overlayCoordinator
    self.warningCoordinator = warningCoordinator
    self.launchAtLogin = launchAtLogin
    self.updatePreferences = updatePreferences
    self.cliInstaller = cliInstaller

    self.overlayCoordinator.onUserSkip = { [weak self] in
      await self?.send(.skip(source: .warning))
    }
    self.overlayCoordinator.onFailOpen = { [weak self] in
      await self?.send(.skip(source: .recovery))
    }
    self.warningCoordinator.onStartNow = { [weak self] in
      await self?.send(.startNow)
    }
    self.warningCoordinator.onSnooze = { [weak self] in
      await self?.send(.snooze(source: .warning))
    }
    self.warningCoordinator.onSkip = { [weak self] in
      await self?.send(.skip(source: .warning))
    }
  }

  /// Opens the default Application Support store and builds a production owner.
  static func makeDefault() throws -> FocusRuntimeOwner {
    let url = try FocusSupportPaths.databaseURL()
    let store = try FocusEventStore(fileURL: url)
    return FocusRuntimeOwner(store: store)
  }

  /// Loads snapshot, starts IPC, and begins the wake loop.
  func bootstrap() async {
    guard !isBootstrapped else { return }
    isBootstrapped = true

    do {
      if let snapshot = try await store.loadSnapshot() {
        runtime = snapshot
      }
    } catch {
      runtime = nil
    }

    await send(.reconcile)
    await startControlListener()
    updatePreferences.startUpdaterIfNeeded()
  }

  func shutdown() async {
    wakeLoopTask?.cancel()
    wakeLoopTask = nil
    await wakeScheduler.cancel()
    await controlServer?.stop()
    controlServer = nil
    warningCoordinator.tearDown()
    overlayCoordinator.endSession()
  }

  /// Menu / overlay / warning intents.
  func send(_ intent: SessionIntent) async {
    let now = clock.now
    let reduction = SessionReducer.reduce(
      runtime: runtime,
      intent: intent,
      at: now,
      ids: &ids
    )
    await apply(reduction)
  }

  /// IPC entry point (invoked via ``ControlMailbox`` on the main actor).
  func handleControlRequest(_ request: ControlRequest) async -> ControlResponse {
    let now = clock.now
    let app = ControlAppInfo.running()
    let previous = runtime
    let result = processor.process(
      request: request,
      runtime: runtime,
      at: now,
      ids: &ids,
      app: app
    )
    if let next = result.runtime {
      let mutated = previous != next || !result.events.isEmpty
      if mutated {
        let directive = Self.presentation(for: next.phase)
        runtime = next
        presentation = directive
        if result.response.ok {
          lastCommandResult =
            result.response.result?.performed == true ? .performed : .noop
        } else {
          lastCommandResult = .rejected(.invalidForPhase)
        }
        do {
          try await store.commit(snapshot: next, events: result.events)
        } catch {
          // Persistence failure must not leave the IPC peer without a response.
        }
        await applyPresentation(directive)
        rescheduleWake()
      }
    }
    return result.response
  }

  /// Readable phase label for the menu.
  var phaseLabel: String {
    guard let runtime else { return "Idle" }
    switch runtime.phase {
    case .focus:
      return "Focus"
    case .warning:
      return "Warning"
    case .breakTime:
      return "Break"
    case .paused:
      return "Paused"
    }
  }

  /// Remaining time until the next transition, for menu display.
  var remainingDescription: String {
    guard let runtime else { return "Not started" }
    let now = clock.now
    switch runtime.phase {
    case .focus(let focus):
      return Self.formatRemaining(focus.warningStartsAt.timeIntervalSince(now)) + " until warning"
    case .warning(let warning):
      return Self.formatRemaining(warning.breakDueAt.timeIntervalSince(now)) + " until break"
    case .breakTime(let breakPhase):
      return Self.formatRemaining(breakPhase.breakEndsAt.timeIntervalSince(now)) + " remaining"
    case .paused(let paused):
      switch paused.remaining {
      case .focus(let untilWarning, _):
        return Self.formatRemaining(untilWarning) + " frozen until warning"
      case .warning(let untilBreak):
        return Self.formatRemaining(untilBreak) + " frozen until break"
      case .breakTime(let untilEnd):
        return Self.formatRemaining(untilEnd) + " frozen on break"
      }
    }
  }

  var canPause: Bool {
    guard let runtime else { return false }
    switch runtime.phase {
    case .paused:
      return false
    case .focus, .warning, .breakTime:
      return true
    }
  }

  var canResume: Bool {
    guard let runtime else { return false }
    if case .paused = runtime.phase { return true }
    return false
  }

  var canSkip: Bool {
    guard let runtime else { return false }
    switch runtime.phase {
    case .warning, .breakTime:
      return true
    case .focus, .paused:
      return false
    }
  }

  var canTriggerBreak: Bool {
    guard let runtime else { return true }
    switch runtime.phase {
    case .breakTime:
      return false
    case .focus, .warning, .paused:
      return true
    }
  }

  var canSnooze: Bool {
    guard let runtime else { return false }
    if case .warning = runtime.phase { return true }
    return false
  }

  // MARK: - Private

  private func apply(_ reduction: SessionReduction) async {
    runtime = reduction.runtime
    presentation = reduction.presentation
    lastCommandResult = reduction.commandResult
    do {
      try await store.commit(snapshot: reduction.runtime, events: reduction.events)
    } catch {
      // Keep in-memory authority even if disk write fails; next commit retries.
    }
    await applyPresentation(reduction.presentation)
    rescheduleWake()
  }

  private func applyPresentation(_ directive: PresentationDirective) async {
    guard !isApplyingPresentation else { return }
    isApplyingPresentation = true
    defer { isApplyingPresentation = false }

    switch directive {
    case .none, .hideWhilePaused:
      warningCoordinator.tearDown()
      overlayCoordinator.endSession()
    case .showWarning:
      overlayCoordinator.endSession()
      warningCoordinator.present()
    case .showBreakOverlay:
      warningCoordinator.tearDown()
      overlayCoordinator.beginSession()
    }
  }

  private func rescheduleWake() {
    wakeLoopTask?.cancel()
    guard let deadline = runtime?.phase.nextDeadline else {
      Task { await wakeScheduler.cancel() }
      return
    }
    wakeLoopTask = Task { [weak self] in
      guard let self else { return }
      await self.wakeScheduler.waitUntil(deadline)
      guard !Task.isCancelled else { return }
      await self.send(.reconcile)
    }
  }

  private func startControlListener() async {
    do {
      let socketURL = try DefaultControlSocketPathResolver().resolveSocketURL()
      let mailbox = ControlMailbox { [weak self] request in
        guard let self else {
          return ControlResponse.failure(
            requestId: request.requestId,
            app: .notRunning,
            error: .appNotRunning()
          )
        }
        return await self.handleControlRequest(request)
      }
      controlMailbox = mailbox
      let server = ControlSocketServer(socketPath: socketURL) { request in
        await mailbox.submit(request)
      }
      try await server.start()
      controlServer = server
    } catch {
      controlServer = nil
    }
  }

  private static func presentation(for phase: SessionPhase) -> PresentationDirective {
    switch phase {
    case .focus:
      return .none
    case .warning:
      return .showWarning
    case .breakTime:
      return .showBreakOverlay
    case .paused:
      return .hideWhilePaused
    }
  }

  private static func formatRemaining(_ interval: TimeInterval) -> String {
    let total = max(0, Int(interval.rounded(.down)))
    let minutes = total / 60
    let seconds = total % 60
    if minutes > 0 {
      return "\(minutes)m \(seconds)s"
    }
    return "\(seconds)s"
  }
}
