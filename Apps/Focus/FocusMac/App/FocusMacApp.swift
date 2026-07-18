import AppKit
import FocusPersistence
import SwiftUI

@main
struct FocusMacApp: App {
  @State private var owner: FocusRuntimeOwner
  @State private var bootstrapFailed = false

  init() {
    if let produced = try? FocusRuntimeOwner.makeDefault() {
      _owner = State(initialValue: produced)
      _bootstrapFailed = State(initialValue: false)
    } else if let memoryStore = try? FocusEventStore(path: ":memory:") {
      _owner = State(initialValue: FocusRuntimeOwner(store: memoryStore))
      _bootstrapFailed = State(initialValue: true)
    } else {
      preconditionFailure("Focus could not open a session store.")
    }
  }

  var body: some Scene {
    MenuBarExtra {
      FocusSessionMenuView(owner: owner)

      Divider()

      SettingsMenuSection(owner: owner)
      CLIControlMenuSection(owner: owner)

      if bootstrapFailed {
        Text("Using temporary session storage")
          .foregroundStyle(.secondary)
      }

      Divider()

      Button("Quit Focus") {
        Task {
          await owner.shutdown()
          NSApp.terminate(nil)
        }
      }
      .keyboardShortcut("q")
      .accessibilityLabel("Quit Focus")
      .accessibilityIdentifier("focus.mac.menu.quit")
    } label: {
      Label("Focus", systemImage: "timer")
        .accessibilityLabel("Focus")
        .accessibilityIdentifier("focus.mac.menubar.status")
    }
    .menuBarExtraStyle(.menu)
    .task {
      await owner.bootstrap()
    }
  }
}
