import AppKit

/// Narrow activation helpers for overlay / warning keyboard focus.
enum AppKitActivation {
  @MainActor
  static func activateForOverlay() {
    NSApp.activate(ignoringOtherApps: true)
  }
}
