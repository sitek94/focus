import XCTest

/// Minimal iOS launch / root-scene smoke.
///
/// Stable accessibility identifiers on FocusIOS:
/// - `focus.ios.root` — root scene container
/// - `focus.ios.brand` — brand title ("Focus")
/// - `focus.ios.status` — non-released shell status placeholder
final class FocusIOSUITests: XCTestCase {
  func testLaunchShowsRootSceneStatusPlaceholder() throws {
    let app = XCUIApplication()
    app.launch()

    let root = app.descendants(matching: .any)["focus.ios.root"]
    XCTAssertTrue(root.waitForExistence(timeout: 10), "Expected focus.ios.root root scene")

    let brand = app.staticTexts["focus.ios.brand"]
    XCTAssertTrue(brand.waitForExistence(timeout: 5), "Expected focus.ios.brand")
    XCTAssertEqual(brand.label, "Focus")

    let status = app.staticTexts["focus.ios.status"]
    XCTAssertTrue(status.waitForExistence(timeout: 5), "Expected focus.ios.status")
    XCTAssertTrue(
      status.label.contains("Non-released iOS shell"),
      "Status should state the iOS shell is non-released; got: \(status.label)"
    )
  }
}
