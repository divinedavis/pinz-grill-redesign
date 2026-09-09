import XCTest

/// App Store screenshot capture. Skipped unless `SCREENSHOT_DIR` is set, so it
/// stays out of the normal `run_tests.sh` sweep — it is a capture run, not an
/// assertion suite. `scripts/capture_screenshots.sh` sets the variable
/// (`TEST_RUNNER_SCREENSHOT_DIR`) and runs this class on an iPhone 17 Pro Max,
/// whose 1320x2868 frames are what `asc_make_screenshots.py` composes from.
///
/// Runs live (no `-offline`) so the menu carries the LIVE badge and real photos.
final class MarketingScreenshots: XCTestCase {
    private var app: XCUIApplication!
    private var dir: String?

    override func setUpWithError() throws {
        continueAfterFailure = true
        dir = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"]
        app = XCUIApplication()
        app.launch()
    }

    private func snap(_ name: String) {
        guard let dir, !dir.isEmpty else { return }
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        try? XCUIScreen.main.screenshot().pngRepresentation
            .write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name).png"))
    }

    private func openTab(_ name: String) {
        let b = app.tabBars.buttons[name]
        XCTAssertTrue(b.waitForExistence(timeout: 10), "tab \(name)")
        b.tap()
        if !b.isSelected { b.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap() }
    }

    func testCaptureScreens() throws {
        guard let dir, !dir.isEmpty else { throw XCTSkip("set SCREENSHOT_DIR to capture screenshots") }

        XCTAssertTrue(app.buttons["home-order-pickup"].waitForExistence(timeout: 30))
        sleep(4)   // live menu + hero photos
        snap("01-home")

        app.swipeUp()
        sleep(1)
        snap("02-home-categories")

        openTab("Menu")
        let item = app.buttons.matching(identifier: "menu-item").firstMatch
        XCTAssertTrue(item.waitForExistence(timeout: 15))
        sleep(3)   // item photos
        snap("03-menu")

        // A wings item is the strongest detail page: photo + sauce choices.
        let wings = app.buttons.matching(identifier: "menu-item")
            .matching(NSPredicate(format: "label CONTAINS[c] 'wing'")).firstMatch
        (wings.exists ? wings : item).tap()
        XCTAssertTrue(app.buttons["item-order-pickup"].waitForExistence(timeout: 10))
        sleep(3)
        snap("04-item")
        app.buttons["Done"].tap()

        openTab("Order")
        XCTAssertTrue(app.buttons["order-tab-pickup"].waitForExistence(timeout: 10))
        sleep(1)
        snap("05-order")

        openTab("Info")
        XCTAssertTrue(app.staticTexts["info-address"].waitForExistence(timeout: 10))
        sleep(1)
        snap("06-info")

        // The handoff itself: ChowNow's checkout inside the app.
        openTab("Home")
        let delivery = app.buttons["home-order-delivery"]
        XCTAssertTrue(delivery.waitForExistence(timeout: 10))
        delivery.tap()
        if app.buttons["Done"].waitForExistence(timeout: 20) {
            sleep(8)
            snap("07-checkout")
            app.buttons["Done"].tap()
        }
        print("screenshots written to \(dir)")
    }
}
