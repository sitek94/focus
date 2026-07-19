import XCTest

/// Minimal iOS launch / root-scene smoke.
///
/// Stable accessibility identifiers on FocusIOS:
/// - `focus.ios.root` — root scene container
/// - `focus.ios.brand` — brand title ("Focus")
/// - `focus.ios.version` — marketing version / build / commit label
final class FocusIOSUITests: XCTestCase {
  func testLaunchShowsRootSceneVersionLabel() throws {
    let app = XCUIApplication()
    app.launch()

    let root = app.descendants(matching: .any)["focus.ios.root"]
    XCTAssertTrue(root.waitForExistence(timeout: 10), "Expected focus.ios.root root scene")

    let brand = app.staticTexts["focus.ios.brand"]
    XCTAssertTrue(brand.waitForExistence(timeout: 5), "Expected focus.ios.brand")
    XCTAssertEqual(brand.label, "Focus")

    let version = app.staticTexts["focus.ios.version"]
    XCTAssertTrue(version.waitForExistence(timeout: 5), "Expected focus.ios.version")
    XCTAssertTrue(
      version.label.hasPrefix("Focus "),
      "Version label should start with Focus; got: \(version.label)"
    )
    XCTAssertTrue(
      version.label.contains("(") && version.label.contains(")"),
      "Version label should include a build number in parentheses; got: \(version.label)"
    )
  }
}
