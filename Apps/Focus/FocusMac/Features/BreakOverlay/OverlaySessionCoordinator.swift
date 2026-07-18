import AppKit
import CoreGraphics
import Foundation

/// `@MainActor` owner of multi-display break overlay windows (PLAN §10).
@MainActor
final class OverlaySessionCoordinator {
  var onUserSkip: (@MainActor () async -> Void)?
  /// Fail-open path when topology/window construction cannot cover the user safely.
  var onFailOpen: (@MainActor () async -> Void)?

  private var windows: [CGDirectDisplayID: OverlayWindowController] = [:]
  private var primaryDisplayID: CGDirectDisplayID?
  private var screenObserver: NSObjectProtocol?
  private var isActive = false
  private var isTearingDown = false

  /// Creates one borderless window per current display. Idempotent while active.
  func beginSession() {
    if isActive {
      reconcileDisplays()
      return
    }
    isActive = true
    isTearingDown = false
    startObservingScreens()
    do {
      try buildWindows(for: DisplayIdentity.currentDisplays())
      AppKitActivation.activateForOverlay()
    } catch {
      failOpen()
    }
  }

  /// Idempotent end-session path: closes every overlay window.
  func endSession() {
    guard !isTearingDown else { return }
    isTearingDown = true
    stopObservingScreens()
    for controller in windows.values {
      controller.close()
    }
    windows.removeAll()
    primaryDisplayID = nil
    isActive = false
    isTearingDown = false
  }

  private func startObservingScreens() {
    guard screenObserver == nil else { return }
    screenObserver = NotificationCenter.default.addObserver(
      forName: NSApplication.didChangeScreenParametersNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      Task { @MainActor [weak self] in
        self?.handleScreenParametersChanged()
      }
    }
  }

  private func stopObservingScreens() {
    if let screenObserver {
      NotificationCenter.default.removeObserver(screenObserver)
      self.screenObserver = nil
    }
  }

  private func handleScreenParametersChanged() {
    guard isActive else { return }
    do {
      try reconcileDisplaysThrowing()
    } catch {
      failOpen()
    }
  }

  private func reconcileDisplays() {
    do {
      try reconcileDisplaysThrowing()
    } catch {
      failOpen()
    }
  }

  private func reconcileDisplaysThrowing() throws {
    let current = DisplayIdentity.currentDisplays()
    guard !current.isEmpty else {
      throw OverlayError.noDisplays
    }
    let currentIDs = Set(current.map(\.displayID))
    let existingIDs = Set(windows.keys)

    for removed in existingIDs.subtracting(currentIDs) {
      windows[removed]?.close()
      windows[removed] = nil
    }

    for display in current {
      if let existing = windows[display.displayID] {
        existing.updateFrame(display.frame)
        existing.updateContent(makeContent(isPrimary: display.displayID == primaryDisplayID))
      } else {
        let isPrimary = primaryDisplayID == nil
        let controller = OverlayWindowController(
          display: display,
          content: makeContent(isPrimary: isPrimary),
          primary: isPrimary
        )
        windows[display.displayID] = controller
        if isPrimary {
          primaryDisplayID = display.displayID
        }
      }
    }

    if let primaryDisplayID, windows[primaryDisplayID] == nil {
      self.primaryDisplayID = windows.keys.sorted().first
      if let newPrimary = self.primaryDisplayID {
        windows[newPrimary]?.makeKey()
        windows[newPrimary]?.updateContent(makeContent(isPrimary: true))
      }
    }

    guard !windows.isEmpty else {
      throw OverlayError.windowConstructionFailed
    }
  }

  private func buildWindows(for displays: [DisplayIdentity]) throws {
    guard !displays.isEmpty else {
      throw OverlayError.noDisplays
    }
    primaryDisplayID = displays[0].displayID
    for display in displays {
      let isPrimary = display.displayID == primaryDisplayID
      let controller = OverlayWindowController(
        display: display,
        content: makeContent(isPrimary: isPrimary),
        primary: isPrimary
      )
      windows[display.displayID] = controller
    }
  }

  private func makeContent(isPrimary: Bool) -> BreakOverlayView {
    BreakOverlayView(isPrimary: isPrimary) { [weak self] in
      Task { await self?.handleSkip() }
    }
  }

  private func handleSkip() async {
    endSession()
    await onUserSkip?()
  }

  private func failOpen() {
    endSession()
    Task { await onFailOpen?() }
  }
}

enum OverlayError: Error {
  case noDisplays
  case windowConstructionFailed
}
