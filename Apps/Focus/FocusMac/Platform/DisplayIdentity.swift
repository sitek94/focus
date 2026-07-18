import AppKit
import CoreGraphics
import Foundation

/// Session-local display identity from `NSScreenNumber` / `CGDirectDisplayID`.
struct DisplayIdentity: Hashable, Sendable {
  var displayID: CGDirectDisplayID
  var frame: CGRect

  /// Reads `NSScreenNumber` from a screen device description.
  static func from(screen: NSScreen) -> DisplayIdentity? {
    from(deviceDescription: screen.deviceDescription, frame: screen.frame)
  }

  /// Testable seam over screen device dictionaries.
  static func from(
    deviceDescription: [NSDeviceDescriptionKey: Any],
    frame: CGRect
  ) -> DisplayIdentity? {
    let key = NSDeviceDescriptionKey("NSScreenNumber")
    guard let number = deviceDescription[key] as? NSNumber else {
      return nil
    }
    return DisplayIdentity(
      displayID: CGDirectDisplayID(number.uint32Value),
      frame: frame
    )
  }

  /// All current displays, or a topology error if any screen lacks `NSScreenNumber`.
  ///
  /// Fail-open: never silently under-cover by skipping unidentified screens.
  static func currentDisplays(screens: [NSScreen] = NSScreen.screens) throws -> [DisplayIdentity] {
    var identities: [DisplayIdentity] = []
    identities.reserveCapacity(screens.count)
    for screen in screens {
      guard let identity = from(screen: screen) else {
        throw OverlayError.missingDisplayIdentity
      }
      identities.append(identity)
    }
    return identities
  }
}
