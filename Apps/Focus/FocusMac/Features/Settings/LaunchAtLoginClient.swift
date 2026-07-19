import Foundation
import ServiceManagement

/// Injected seam over `SMAppService.mainApp`.
@MainActor
final class LaunchAtLoginClient {
  enum Status: Equatable, Sendable {
    case notRegistered
    case enabled
    case requiresApproval
    case notFound
  }

  private let service: SMAppService
  private let openSettings: () -> Void

  init(
    service: SMAppService = .mainApp,
    openSettings: @escaping () -> Void = { SMAppService.openSystemSettingsLoginItems() }
  ) {
    self.service = service
    self.openSettings = openSettings
  }

  /// Authoritative launch-at-login status from Service Management.
  var status: Status {
    switch service.status {
    case .notRegistered:
      return .notRegistered
    case .enabled:
      return .enabled
    case .requiresApproval:
      return .requiresApproval
    case .notFound:
      return .notFound
    @unknown default:
      return .notFound
    }
  }

  var isEnabled: Bool { status == .enabled }

  var needsUserApproval: Bool {
    switch status {
    case .requiresApproval, .notFound:
      return true
    case .notRegistered, .enabled:
      return false
    }
  }

  func enable() throws {
    try service.register()
  }

  func disable() throws {
    try service.unregister()
  }

  func openSystemSettingsLoginItems() {
    openSettings()
  }
}
