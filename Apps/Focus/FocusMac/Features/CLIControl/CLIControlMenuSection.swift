import SwiftUI

/// Menu actions for installing/repairing the `focus` CLI symlink.
struct CLIControlMenuSection: View {
  @Bindable var owner: FocusRuntimeOwner
  @State private var statusMessage: String = ""

  var body: some View {
    Menu("Command Line Tool") {
      Button(actionTitle) {
        performInstallOrRepair()
      }
      .disabled(isActionDisabled)
      .accessibilityLabel(actionTitle)

      if !statusMessage.isEmpty {
        Text(statusMessage)
          .foregroundStyle(.secondary)
      }
    }
    .onAppear(perform: refresh)
  }

  private var state: CLIInstaller.State {
    owner.cliInstaller.currentState()
  }

  private var actionTitle: String {
    switch state {
    case .notInstalled, .bundledToolMissing:
      return "Install Command Line Tool…"
    case .installed, .needsRepair:
      return "Repair Command Line Tool…"
    case .blockedByTranslocation:
      return "Install Command Line Tool…"
    }
  }

  private var isActionDisabled: Bool {
    switch state {
    case .blockedByTranslocation, .bundledToolMissing:
      return true
    case .notInstalled, .installed, .needsRepair:
      return false
    }
  }

  private func refresh() {
    switch state {
    case .notInstalled:
      statusMessage = "Not installed (\(owner.cliInstaller.preferredSymlinkURL.path))"
    case .installed(let symlink, _):
      statusMessage = "Installed at \(symlink.path)"
    case .needsRepair:
      statusMessage = "Needs repair"
    case .blockedByTranslocation:
      statusMessage = "Move Focus to /Applications before installing the CLI"
    case .bundledToolMissing:
      statusMessage = "Bundled focus tool is missing"
    }
  }

  private func performInstallOrRepair() {
    do {
      let url = try owner.cliInstaller.installOrRepair()
      statusMessage = "Linked \(url.path)"
      if let instruction = owner.cliInstaller.pathInstructionIfNeeded() {
        statusMessage += " — \(instruction)"
      }
    } catch CLIInstaller.InstallError.translocated {
      statusMessage = "Move Focus to /Applications before installing the CLI"
    } catch CLIInstaller.InstallError.bundledToolMissing {
      statusMessage = "Bundled focus tool is missing"
    } catch {
      statusMessage = "CLI install failed"
    }
  }
}
