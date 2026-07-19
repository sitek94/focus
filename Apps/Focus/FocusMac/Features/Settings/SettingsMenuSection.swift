import SwiftUI

/// Settings owned by this feature: launch at login and updates. No timing knobs.
struct SettingsMenuSection: View {
  @Bindable var owner: FocusRuntimeOwner
  @State private var loginStatus: LaunchAtLoginClient.Status = .notRegistered
  @State private var automaticUpdates = true

  var body: some View {
    Menu("Settings") {
      launchAtLoginControls
      Divider()
      updateControls
    }
    .onAppear(perform: refresh)
  }

  @ViewBuilder
  private var launchAtLoginControls: some View {
    Button(loginToggleTitle) {
      toggleLaunchAtLogin()
    }
    .accessibilityLabel(loginToggleTitle)
    .accessibilityHint(loginAccessibilityHint)

    if owner.launchAtLogin.needsUserApproval {
      Button("Open Login Items Settings…") {
        owner.launchAtLogin.openSystemSettingsLoginItems()
      }
      .accessibilityLabel("Open Login Items Settings")
      .accessibilityHint("Approve or revoke Focus in System Settings")
    }

    Text(loginStatusDescription)
      .foregroundStyle(.secondary)
  }

  @ViewBuilder
  private var updateControls: some View {
    Text(BuildInfo.menuLabel)
      .foregroundStyle(.secondary)
      .accessibilityLabel(BuildInfo.menuLabel)

    Toggle(
      "Check for Updates Automatically",
      isOn: Binding(
        get: { automaticUpdates },
        set: { newValue in
          automaticUpdates = newValue
          owner.updatePreferences.automaticallyChecksForUpdates = newValue
        }
      )
    )
    .accessibilityLabel("Check for updates automatically")

    Button("Check for Updates…") {
      owner.updatePreferences.checkForUpdates()
    }
    .disabled(!owner.updatePreferences.canCheckForUpdates)
    .accessibilityLabel("Check for updates")
  }

  private var loginToggleTitle: String {
    switch loginStatus {
    case .enabled:
      return "Disable Launch at Login"
    case .notRegistered, .requiresApproval, .notFound:
      return "Enable Launch at Login"
    }
  }

  private var loginStatusDescription: String {
    switch loginStatus {
    case .notRegistered:
      return "Launch at login: Off"
    case .enabled:
      return "Launch at login: On"
    case .requiresApproval:
      return "Launch at login: Needs approval"
    case .notFound:
      return "Launch at login: Unavailable"
    }
  }

  private var loginAccessibilityHint: String {
    switch loginStatus {
    case .enabled:
      return "Stops Focus from opening when you log in"
    case .requiresApproval:
      return "Registers Focus, then open Login Items if macOS asks for approval"
    case .notRegistered, .notFound:
      return "Opens Focus automatically when you log in"
    }
  }

  private func refresh() {
    loginStatus = owner.launchAtLogin.status
    automaticUpdates = owner.updatePreferences.automaticallyChecksForUpdates
  }

  private func toggleLaunchAtLogin() {
    do {
      switch owner.launchAtLogin.status {
      case .enabled:
        try owner.launchAtLogin.disable()
      case .notRegistered, .requiresApproval, .notFound:
        try owner.launchAtLogin.enable()
      }
    } catch {
      // Surface authoritative status after a failed register/unregister.
    }
    refresh()
  }
}
