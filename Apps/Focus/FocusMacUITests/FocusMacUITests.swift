import XCTest

/// Minimal macOS launch / menu smoke (PLAN §12).
///
/// Stable accessibility identifiers on FocusMac:
/// - `focus.mac.menubar.status` — MenuBarExtra label
/// - `focus.mac.menu.title` — menu phase title
/// - `focus.mac.menu.quit` — Quit Focus
///
/// MenuBarExtra items may also match by label ("Focus" / "Quit Focus") when
/// the status-item host does not expose identifiers to XCUITest.
final class FocusMacUITests: XCTestCase {
  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  func testLaunchMenuBarExtraExists() throws {
    let app = XCUIApplication()
    app.launch()

    XCTAssertTrue(
      app.wait(for: .runningForeground, timeout: 5) || app.exists,
      "FocusMac should launch as a running LSUIElement process"
    )

    let menuBar = app.menuBars.firstMatch
    XCTAssertTrue(
      menuBar.waitForExistence(timeout: 10),
      "Expected a menu bar host for MenuBarExtra"
    )

    let statusById = app.descendants(matching: .any)["focus.mac.menubar.status"]
    let statusByLabel = menuBar.menuItems["Focus"]
    let statusByStatusItem = app.statusItems["Focus"]
    XCTAssertTrue(
      statusById.waitForExistence(timeout: 5)
        || statusByLabel.waitForExistence(timeout: 2)
        || statusByStatusItem.waitForExistence(timeout: 2)
        || app.menuItems["Quit Focus"].waitForExistence(timeout: 2)
        || app.descendants(matching: .any)["focus.mac.menu.quit"].waitForExistence(timeout: 2),
      "Expected Focus MenuBarExtra via identifier or Focus/Quit Focus labels"
    )
  }
}
