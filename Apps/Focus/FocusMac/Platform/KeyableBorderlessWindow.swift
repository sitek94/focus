import AppKit

/// Borderless window that can become key for Escape / keyboard handling.
final class KeyableBorderlessWindow: NSWindow {
  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { false }
}
