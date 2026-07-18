import SwiftUI

/// Full-display break content with a large Skip control on every screen.
struct BreakOverlayView: View {
  var isPrimary: Bool
  var onSkip: () -> Void

  var body: some View {
    ZStack {
      Color.black.opacity(0.72)
        .ignoresSafeArea()

      VStack(spacing: 28) {
        Text("Break")
          .font(.system(size: 48, weight: .semibold, design: .rounded))
          .foregroundStyle(.white)
          .accessibilityAddTraits(.isHeader)

        Text("Look away from the screen for a moment.")
          .font(.title3)
          .foregroundStyle(.white.opacity(0.85))
          .multilineTextAlignment(.center)

        Button("Skip", action: onSkip)
          .keyboardShortcut(.escape, modifiers: [])
          .controlSize(.large)
          .buttonStyle(.borderedProminent)
          .tint(.white)
          .foregroundStyle(.black)
          .accessibilityLabel("Skip break")
          .accessibilityHint("Ends the break and returns to focus")
          .accessibilitySortPriority(isPrimary ? 1 : 0)
      }
      .padding(48)
      .frame(maxWidth: 560)
    }
    .focusable(isPrimary)
    .onKeyPress(.escape) {
      onSkip()
      return .handled
    }
  }
}
