import Foundation

/// Localization-ready English copy for the non-released iOS shell.
struct FocusIOSShellCopy: Sendable {
  var brand: LocalizedStringResource {
    LocalizedStringResource(
      "focus_ios_brand",
      defaultValue: "Focus",
      comment: "Brand name shown as the iOS shell hero title."
    )
  }

  var status: LocalizedStringResource {
    LocalizedStringResource(
      "focus_ios_status_placeholder",
      defaultValue: "Non-released iOS shell — status placeholder",
      comment: "States that Focus iOS is an unreleased shell showing status only."
    )
  }
}
