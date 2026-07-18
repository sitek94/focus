import AppKit
import SwiftUI

/// One borderless, screen-sized overlay window hosting SwiftUI content.
@MainActor
final class OverlayWindowController {
  let displayID: CGDirectDisplayID
  private let window: NSWindow
  private let hosting: NSHostingView<BreakOverlayView>

  init(display: DisplayIdentity, content: BreakOverlayView, primary: Bool) {
    self.displayID = display.displayID
    let hosting = NSHostingView(rootView: content)
    self.hosting = hosting

    let window = KeyableBorderlessWindow(
      contentRect: display.frame,
      styleMask: [.borderless],
      backing: .buffered,
      defer: false
    )
    window.setFrame(display.frame, display: true)
    window.isReleasedWhenClosed = false
    window.level = .screenSaver
    window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    window.backgroundColor = .clear
    window.isOpaque = false
    window.hasShadow = false
    window.ignoresMouseEvents = false
    window.contentView = hosting
    window.canHide = false
    self.window = window

    if primary {
      window.makeKeyAndOrderFront(nil)
    } else {
      window.orderFrontRegardless()
    }
  }

  func updateContent(_ content: BreakOverlayView) {
    hosting.rootView = content
  }

  func updateFrame(_ frame: CGRect) {
    window.setFrame(frame, display: true)
  }

  func makeKey() {
    window.makeKeyAndOrderFront(nil)
  }

  func close() {
    window.orderOut(nil)
    window.close()
  }
}
