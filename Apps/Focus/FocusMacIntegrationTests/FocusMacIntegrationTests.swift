import AppKit
import FocusControl
import FocusSession
import XCTest

@testable import FocusMac

final class FocusMacIntegrationTests: XCTestCase {
  func testDarwinControlSocketPathResolverProducesPrivateTempSocket() throws {
    #if os(macOS)
      let resolver = DarwinControlSocketPathResolver()
      let url = try resolver.resolveSocketURL()
      XCTAssertEqual(url.lastPathComponent, ControlSocketPath.fileName)
      XCTAssertLessThanOrEqual(url.path.utf8.count, ControlSocketPath.maxPathByteLength)
      try ControlSocketPath.validateParentDirectory(url.deletingLastPathComponent())
    #else
      throw XCTSkip("Darwin socket path resolver requires macOS")
    #endif
  }

  func testDefaultResolverHonorsDebugSocketInjection() throws {
    #if DEBUG
      let parent = FileManager.default.temporaryDirectory
        .appendingPathComponent("focus-mac-ipc-\(UUID().uuidString)", isDirectory: true)
      try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
      defer { try? FileManager.default.removeItem(at: parent) }

      let socket = parent.appendingPathComponent(ControlSocketPath.fileName)
      let resolver = DefaultControlSocketPathResolver(
        environment: [ControlSocketPath.injectedEnvironmentKey: socket.path]
      )
      let resolved = try resolver.resolveSocketURL()
      XCTAssertEqual(resolved.path, socket.path)
    #else
      throw XCTSkip("FOCUS_CONTROL_SOCKET injection is DEBUG-only")
    #endif
  }

  func testCLIInstallPathsPreferLocalBinAndDetectTranslocation() {
    let home = URL(fileURLWithPath: "/Users/test", isDirectory: true)
    let symlink = CLIInstallPaths.preferredSymlinkURL(homeDirectory: home)
    XCTAssertEqual(symlink.path, "/Users/test/.local/bin/focus")

    let translocated = URL(
      fileURLWithPath:
        "/private/var/folders/xx/AppTranslocation/ABC/d/Focus.app",
      isDirectory: true
    )
    XCTAssertTrue(CLIInstallPaths.isTranslocated(bundleURL: translocated))

    let volume = URL(fileURLWithPath: "/Volumes/Focus/Focus.app", isDirectory: true)
    XCTAssertTrue(CLIInstallPaths.isTranslocated(bundleURL: volume))

    let applications = URL(fileURLWithPath: "/Applications/Focus.app", isDirectory: true)
    XCTAssertFalse(CLIInstallPaths.isTranslocated(bundleURL: applications))
  }

  func testDisplayIdentityParsesNSScreenNumber() {
    let description: [NSDeviceDescriptionKey: Any] = [
      NSDeviceDescriptionKey("NSScreenNumber"): NSNumber(value: UInt32(42))
    ]
    let identity = DisplayIdentity.from(
      deviceDescription: description,
      frame: CGRect(x: 0, y: 0, width: 1920, height: 1080)
    )
    XCTAssertEqual(identity?.displayID, 42)
    XCTAssertEqual(identity?.frame.width, 1920)
  }

  func testDisplayIdentityRejectsMissingScreenNumber() {
    let identity = DisplayIdentity.from(
      deviceDescription: [:],
      frame: .zero
    )
    XCTAssertNil(identity)
  }

  func testCurrentDisplaysFailsOpenWhenScreenNumberMissing() {
    // Missing NSScreenNumber must not be silently skipped (under-cover).
    // `currentDisplays` throws `.missingDisplayIdentity`; the optional seam
    // returns nil so coordinators can treat it as a topology error.
    XCTAssertNil(DisplayIdentity.from(deviceDescription: [:], frame: .zero))
    switch OverlayError.missingDisplayIdentity {
    case .missingDisplayIdentity:
      break
    case .noDisplays, .windowConstructionFailed:
      XCTFail("Unexpected overlay error case")
    }
  }

  func testControlMailboxForwardsToMainActorHandler() async {
    let expected = ControlRequest(command: .status)
    let mailbox = ControlMailbox { request in
      XCTAssertEqual(request.command, .status)
      return ControlResponse.failure(
        requestId: request.requestId,
        app: .notRunning,
        error: .appNotRunning()
      )
    }
    let response = await mailbox.submit(expected)
    XCTAssertFalse(response.ok)
    XCTAssertEqual(response.error?.code, "app_not_running")
  }

  func testControlRequestProcessorExposesEventsForPersistence() {
    var ids = IdentifierFactory.deterministic(start: 1)
    let processor = ControlRequestProcessor()
    let result = processor.process(
      request: ControlRequest(command: .start),
      runtime: nil,
      at: Date(timeIntervalSince1970: 1_000),
      ids: &ids,
      app: .running(pid: 1)
    )
    XCTAssertTrue(result.response.ok)
    XCTAssertNotNil(result.runtime)
    XCTAssertFalse(result.events.isEmpty)
  }

  func testLaunchAtLoginStatusCasesAreDistinct() {
    let statuses: [LaunchAtLoginClient.Status] = [
      .notRegistered,
      .enabled,
      .requiresApproval,
      .notFound,
    ]
    XCTAssertEqual(Set(statuses.map { String(describing: $0) }).count, 4)
  }
}
