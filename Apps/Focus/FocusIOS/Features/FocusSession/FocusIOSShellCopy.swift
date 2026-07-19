import Foundation

/// Localization-ready English copy for the iOS root scene.
struct FocusIOSShellCopy: Sendable {
  var brand: LocalizedStringResource {
    LocalizedStringResource(
      "focus_ios_brand",
      defaultValue: "Focus",
      comment: "Brand name shown as the iOS root hero title."
    )
  }
}
