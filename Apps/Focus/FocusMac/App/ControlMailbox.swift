import FocusControl
import Foundation

/// Bridges the IPC listener actor to `@MainActor` session mutations.
///
/// The socket handler captures this Sendable actor; the actor hops onto the
/// main actor via a `@Sendable @MainActor` handler without unsafe escapes.
actor ControlMailbox {
  private let handler: @Sendable @MainActor (ControlRequest) async -> ControlResponse

  init(handler: @escaping @Sendable @MainActor (ControlRequest) async -> ControlResponse) {
    self.handler = handler
  }

  func submit(_ request: ControlRequest) async -> ControlResponse {
    await handler(request)
  }
}
