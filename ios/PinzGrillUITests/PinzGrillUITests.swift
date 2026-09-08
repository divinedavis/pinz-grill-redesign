import XCTest

/// Launch → every tab → item detail → the ordering entry points exist.
/// Runs with `-offline` so it exercises the bundled snapshot only.
final class PinzGrillUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-offline"]
        app.launch()
    }

    /// iOS 26 tab bars: a plain tap can land on the glass and not select; fall back to a coordinate tap.
    private func openTab(_ name: String) {
        let b = app.tabBars.buttons[name]
        XCTAssertTrue(b.waitForExistence(timeout: 10), "tab \(name)")
        b.tap()
        if !b.isSelected { b.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap() }
    }

    func testHomeOffersPickupAndDelivery() {
        XCTAssertTrue(app.buttons["home-order-pickup"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.buttons["home-order-delivery"].exists, "delivery is live on ChowNow for this location")
        XCTAssertTrue(app.staticTexts["status-pill"].exists || app.otherElements["status-pill"].exists)
    }

    /// The whole point of the app: Delivery hands off to ChowNow's hosted checkout in an
    /// in-app Safari sheet (its Done button is the tell), not to an external browser.
    func testDeliveryOpensChowNowCheckoutInApp() {
        let delivery = app.buttons["home-order-delivery"]
        XCTAssertTrue(delivery.waitForExistence(timeout: 20))
        delivery.tap()
        let done = app.buttons["Done"]
        XCTAssertTrue(done.waitForExistence(timeout: 20), "SFSafariViewController did not present")
        XCTAssertEqual(app.state, .runningForeground, "the app stayed in front; no external browser launch")
        sleep(6)   // let ChowNow's page paint for the screenshot
        if let dir = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"] {
            try? XCUIScreen.main.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: dir).appendingPathComponent("shot-delivery.png"))
        }
        done.tap()
        XCTAssertTrue(delivery.waitForExistence(timeout: 10))
    }

    func testMenuListsCategoriesAndOpensAnItem() {
        openTab("Menu")
        let item = app.buttons.matching(identifier: "menu-item").firstMatch
        XCTAssertTrue(item.waitForExistence(timeout: 10))
        XCTAssertGreaterThan(app.buttons.matching(identifier: "menu-item").count, 10)
        item.tap()
        XCTAssertTrue(app.buttons["item-order-pickup"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["item-order-delivery"].exists)
        app.buttons["Done"].tap()
        XCTAssertTrue(item.waitForExistence(timeout: 5))
    }

    func testOrderTabShowsBothModes() {
        openTab("Order")
        XCTAssertTrue(app.buttons["order-tab-pickup"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["order-tab-delivery"].exists)
        XCTAssertTrue(app.staticTexts["$3.99"].exists, "delivery fee from the snapshot")
    }

    func testInfoShowsAddressAndHours() {
        openTab("Info")
        XCTAssertTrue(app.staticTexts["info-address"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["info-address"].label.contains("3601 Broad River"))
        XCTAssertTrue(app.staticTexts["Pickup hours"].exists || app.otherElements["Pickup hours"].exists)
    }
}
