import SwiftUI

/// Compact warning panel: Start now / Snooze 1 minute / Skip.
struct WarningPanelView: View {
  var onStartNow: () -> Void
  var onSnooze: () -> Void
  var onSkip: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Break coming up")
        .font(.headline)
        .accessibilityAddTraits(.isHeader)

      Text("A short break starts in a few seconds.")
        .font(.subheadline)
        .foregroundStyle(.secondary)

      HStack(spacing: 12) {
        Button("Start now", action: onStartNow)
          .keyboardShortcut(.defaultAction)
          .accessibilityLabel("Start break now")
          .accessibilityHint("Begins the break immediately")

        Button("Snooze 1 minute", action: onSnooze)
          .keyboardShortcut("z", modifiers: [.command])
          .accessibilityLabel("Snooze for one minute")
          .accessibilityHint("Delays the break by sixty seconds")

        Button("Skip", action: onSkip)
          .keyboardShortcut(.cancelAction)
          .accessibilityLabel("Skip break")
          .accessibilityHint("Skips this break and continues focusing")
      }
    }
    .padding(20)
    .frame(minWidth: 420)
  }
}
