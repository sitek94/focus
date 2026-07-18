import SwiftUI

/// Thin menu UI: renders phase/remaining and sends intents only.
struct FocusSessionMenuView: View {
  @Bindable var owner: FocusRuntimeOwner

  var body: some View {
    Text(owner.phaseLabel)
      .accessibilityIdentifier("focus.mac.menu.title")
    Text(owner.remainingDescription)
      .foregroundStyle(.secondary)

    Divider()

    Button("Pause") {
      Task { await owner.send(.pause) }
    }
    .disabled(!owner.canPause)
    .accessibilityLabel("Pause focus session")
    .accessibilityHint("Freezes the current timer until you resume")

    Button("Resume") {
      Task { await owner.send(.resume) }
    }
    .disabled(!owner.canResume)
    .accessibilityLabel("Resume focus session")

    Button("Skip") {
      Task { await owner.send(.skip(source: .warning)) }
    }
    .disabled(!owner.canSkip)
    .keyboardShortcut("s", modifiers: [.command])
    .accessibilityLabel("Skip warning or break")

    Button("Start Break Now") {
      Task { await owner.send(.triggerBreak) }
    }
    .disabled(!owner.canTriggerBreak)
    .accessibilityLabel("Start break now")

    Button("Snooze 1 Minute") {
      Task { await owner.send(.snooze(source: .warning)) }
    }
    .disabled(!owner.canSnooze)
    .accessibilityLabel("Snooze break for one minute")
  }
}
