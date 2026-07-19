import Foundation
import Sparkle

/// Wraps Sparkle’s automatic-check preference and updater UI.
@MainActor
final class UpdatePreferencesClient {
  private let controller: SPUStandardUpdaterController
  private var didStart = false

  init(startingUpdater: Bool = false) {
    controller = SPUStandardUpdaterController(
      startingUpdater: startingUpdater,
      updaterDelegate: nil,
      userDriverDelegate: nil
    )
  }

  /// Sparkle-owned automatic update check preference.
  var automaticallyChecksForUpdates: Bool {
    get { controller.updater.automaticallyChecksForUpdates }
    set { controller.updater.automaticallyChecksForUpdates = newValue }
  }

  var canCheckForUpdates: Bool {
    controller.updater.canCheckForUpdates
  }

  func startUpdaterIfNeeded() {
    guard !didStart else { return }
    didStart = true
    controller.startUpdater()
  }

  func checkForUpdates() {
    controller.checkForUpdates(nil)
  }
}
