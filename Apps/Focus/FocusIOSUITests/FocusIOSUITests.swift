import XCTest

final class FocusIOSUITests: XCTestCase {
  func testLaunchPlaceholder() throws {
    let app = XCUIApplication()
    app.launch()
    XCTAssertTrue(app.exists)
  }
}
