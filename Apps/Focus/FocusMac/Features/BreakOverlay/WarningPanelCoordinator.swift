import AppKit
import SwiftUI

/// Owns the single compact warning panel on the main display.
@MainActor
final class WarningPanelCoordinator {
  var onStartNow: (@MainActor () async -> Void)?
  var onSnooze: (@MainActor () async -> Void)?
  var onSkip: (@MainActor () async -> Void)?

  private var window: NSWindow?
  private var hosting: NSHostingView<WarningPanelView>?

  func present() {
    if window != nil {
      window?.makeKeyAndOrderFront(nil)
      return
    }

    let content = WarningPanelView(
      onStartNow: { [weak self] in
        Task { await self?.onStartNow?() }
      },
      onSnooze: { [weak self] in
        Task { await self?.onSnooze?() }
      },
      onSkip: { [weak self] in
        Task { await self?.onSkip?() }
      }
    )
    let hosting = NSHostingView(rootView: content)
    self.hosting = hosting

    let panel = NSPanel(
      contentRect: NSRect(x: 0, y: 0, width: 460, height: 160),
      styleMask: [.titled, .closable, .nonactivatingPanel, .fullSizeContentView],
      backing: .buffered,
      defer: false
    )
    panel.title = "Focus"
    panel.isFloatingPanel = true
    panel.level = .floating
    panel.hidesOnDeactivate = false
    panel.isReleasedWhenClosed = false
    panel.contentView = hosting
    panel.center()
    if let screen = NSScreen.main {
      let frame = panel.frame
      let x = screen.visibleFrame.midX - frame.width / 2
      let y = screen.visibleFrame.midY - frame.height / 2
      panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
    panel.makeKeyAndOrderFront(nil)
    AppKitActivation.activateForOverlay()
    window = panel
  }

  func tearDown() {
    window?.orderOut(nil)
    window?.close()
    window = nil
    hosting = nil
  }
}
