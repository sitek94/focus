import Foundation

/// Launches the sibling Focus app when the control socket is absent.
public protocol AppLauncherClient: Sendable {
  /// Request that the Focus app start. May return before the socket is ready.
  func launchFocusApp() async throws
}

/// Default launcher that refuses to cold-start (used when no platform hook exists).
public struct UnavailableAppLauncherClient: AppLauncherClient {
  public init() {}

  public func launchFocusApp() async throws {
    throw ControlTransportError.appNotRunning
  }
}

/// Records launch requests for Linux CLI integration tests.
public actor RecordingAppLauncherClient: AppLauncherClient {
  public private(set) var launchCount = 0
  private let onLaunch: @Sendable () async throws -> Void

  public init(onLaunch: @escaping @Sendable () async throws -> Void = {}) {
    self.onLaunch = onLaunch
  }

  public func launchFocusApp() async throws {
    launchCount += 1
    try await onLaunch()
  }
}
