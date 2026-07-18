import FocusControl
import FocusPersistence
import FocusSession
import Foundation
import Testing

@Test
func portableModulesAreAvailable() {
  #expect(FocusSessionModule.moduleName == "FocusSession")
  #expect(FocusControlModule.moduleName == "FocusControl")
  #expect(FocusPersistenceModule.moduleName == "FocusPersistence")
}

@Test
func portableSourcesDoNotImportAppleUIFrameworks() throws {
  let roots = ["Sources/FocusSession", "Sources/FocusControl", "Sources/FocusPersistence", "CLI"]
  let banned = ["import AppKit", "import SwiftUI", "import UIKit", "import Cocoa"]
  var violations: [String] = []

  for root in roots {
    let url = URL(fileURLWithPath: root, isDirectory: true)
    guard let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: nil)
    else {
      continue
    }
    for case let file as URL in enumerator where file.pathExtension == "swift" {
      let contents = try String(contentsOf: file, encoding: .utf8)
      for token in banned where contents.contains(token) {
        violations.append("\(file.path): \(token)")
      }
    }
  }
  #expect(violations.isEmpty, "Apple UI imports leaked into portable sources: \(violations)")
}

@Test
func peerAndLaunchSeamsAreInjectable() throws {
  let sameUser = SameUserPeerIdentityChecker()
  try sameUser.verifyPeer(fileDescriptor: 0)

  let defaultChecker = ControlPeerIdentity.makeDefaultChecker()
  #expect(defaultChecker is SameUserPeerIdentityChecker)

  #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
    let darwin: any ControlPeerIdentityChecking = DarwinPeerIdentityChecker()
    #expect(darwin is DarwinPeerIdentityChecker)
    _ = DarwinControlSocketPathResolver()
  #else
    // Darwin getpeereid / _CS_DARWIN_USER_TEMP_DIR types are compiled out on Linux.
    #expect(!(defaultChecker is NSObject))
  #endif
}

@Test
func defaultSocketResolverHonorsDebugInjection() throws {
  let parent = URL(
    fileURLWithPath: "/tmp/g\(String(UUID().uuidString.prefix(8)))", isDirectory: true)
  try ControlSocketPath.ensurePrivateDirectory(parent)
  defer { try? FileManager.default.removeItem(at: parent) }
  let socket = parent.appendingPathComponent(ControlSocketPath.fileName)

  let resolver = DefaultControlSocketPathResolver(
    environment: [ControlSocketPath.injectedEnvironmentKey: socket.path]
  )
  #if DEBUG
    let resolved = try resolver.resolveSocketURL()
    #expect(resolved.path == socket.path)
  #else
    _ = resolver
  #endif
}

@Test
func unavailableLauncherDoesNotImplyAppleFramework() async {
  let launcher: any AppLauncherClient = UnavailableAppLauncherClient()
  do {
    try await launcher.launchFocusApp()
    Issue.record("Expected UnavailableAppLauncherClient to throw")
  } catch let error as ControlTransportError {
    #expect(error == .appNotRunning)
  } catch {
    Issue.record("Unexpected error: \(error)")
  }
}
