import FocusSession
import SwiftUI

/// Minimal iOS root scene: brand plus build / version label.
struct FocusIOSRootView: View {
  private let copy = FocusIOSShellCopy()

  /// Proves the iOS shell links the portable `FocusSession` product.
  private let linkedSessionModule = FocusSessionModule.moduleName

  var body: some View {
    VStack(spacing: 16) {
      Text(copy.brand)
        .font(.largeTitle.weight(.semibold))
        .accessibilityIdentifier(FocusIOSAccessibility.brand)

      Text(BuildInfo.label)
        .font(.body)
        .multilineTextAlignment(.center)
        .foregroundStyle(.secondary)
        .accessibilityIdentifier(FocusIOSAccessibility.version)
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier(FocusIOSAccessibility.root)
    .accessibilityValue(Text(verbatim: linkedSessionModule))
  }
}
