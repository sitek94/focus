import XCTest

final class FocusMacUITests: XCTestCase {
  func testLaunchPlaceholder() throws {
    let app = XCUIApplication()
    app.launch()
    XCTAssertTrue(app.exists)
  }
}
