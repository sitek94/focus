import AppKit
import Foundation
import Sparkle

/// Wraps Sparkle’s automatic-check preference, background checks, and idle relaunch.
@MainActor
final class UpdatePreferencesClient: NSObject, SPUUpdaterDelegate {
  private var controller: SPUStandardUpdaterController!
  private var didStart = false
  private var activationObserver: NSObjectProtocol?
  /// Called when Sparkle has a downloaded update ready to install+relaunch.
  private var pendingImmediateInstall: (() -> Void)?
  /// Gate: return true only when installing won't interrupt warning/break UI.
  var isSafeToInstallUpdate: () -> Bool = { true }

  override init() {
    super.init()
    controller = SPUStandardUpdaterController(
      startingUpdater: false,
      updaterDelegate: self,
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
    checkForUpdatesInBackgroundIfPossible()
    activationObserver = NotificationCenter.default.addObserver(
      forName: NSApplication.didBecomeActiveNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      Task { @MainActor in
        self?.checkForUpdatesInBackgroundIfPossible()
        self?.tryInstallPendingUpdateIfSafe()
      }
    }
  }

  func checkForUpdates() {
    controller.checkForUpdates(nil)
  }

  /// Invoked after session phase changes so a stalled update can install off-break.
  func tryInstallPendingUpdateIfSafe() {
    guard let pendingImmediateInstall, isSafeToInstallUpdate() else { return }
    self.pendingImmediateInstall = nil
    pendingImmediateInstall()
  }

  private func checkForUpdatesInBackgroundIfPossible() {
    guard automaticallyChecksForUpdates else { return }
    guard !controller.updater.sessionInProgress else { return }
    controller.updater.checkForUpdatesInBackground()
  }

  // MARK: - SPUUpdaterDelegate

  func updater(
    _ updater: SPUUpdater,
    willInstallUpdateOnQuit item: SUAppcastItem,
    immediateInstallationBlock immediateInstallHandler: @escaping () -> Void
  ) -> Bool {
    if isSafeToInstallUpdate() {
      DispatchQueue.main.async {
        immediateInstallHandler()
      }
      return true
    }
    pendingImmediateInstall = immediateInstallHandler
    return true
  }
}
