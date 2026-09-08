import XCTest
@testable import PinzGrill

final class PinzGrillTests: XCTestCase {
    private func bundledData(_ name: String) throws -> Data {
        let bundle = Bundle(for: Store.self)
        let url = try XCTUnwrap(bundle.url(forResource: name, withExtension: "json"), "\(name).json missing from the app bundle")
        return try Data(contentsOf: url)
    }

    // The app boots from these; if either stops decoding the app crashes on launch.
    func testBundledSnapshotDecodes() throws {
        let r = try JSONDecoder().decode(Restaurant.self, from: bundledData("restaurant"))
        XCTAssertEqual(r.id, ChowNow.locationId)
        XCTAssertEqual(r.address?.city, "Columbia")
        XCTAssertFalse(r.pickup?.hours.isEmpty ?? true, "pickup hours")
        XCTAssertTrue(r.offersDelivery, "delivery hours are configured on ChowNow")
        XCTAssertEqual(r.delivery?.deliveryFee, 3.99)

        let m = try JSONDecoder().decode(Menu.self, from: bundledData("menu"))
        let catalog = MenuCatalog(m)
        XCTAssertGreaterThan(catalog.categories.count, 5)
        XCTAssertGreaterThan(catalog.allItems.count, 40)
        let names = catalog.categories.map(\.name)
        XCTAssertEqual(names.filter { $0.lowercased().contains("under") }.count, 1, "duplicate Toast category collapsed")
        XCTAssertTrue(names.contains("Drinks · Small") && names.contains("Drinks · Large"))
        let wings = try XCTUnwrap(catalog.allItems.first { $0.name.lowercased().hasPrefix("6 piece") })
        let groups = catalog.modifierGroups(for: wings)
        XCTAssertFalse(groups.isEmpty, "wings carry a flavor modifier group")
        XCTAssertTrue(groups.flatMap(\.options).contains { $0.name.lowercased().contains("lemon") })
    }

    func testSnapshotCarriesNoProcessorKey() throws {
        let text = String(decoding: try bundledData("restaurant"), as: UTF8.self)
        XCTAssertFalse(text.contains("pk_live"), "refresh_snapshot.py must strip the membership block")
    }

    // Mon–Sat 11:00–21:00, Sunday closed — Pinz Grill's pickup schedule.
    private let week: [Restaurant.DisplayDay] = {
        (1...7).map { Restaurant.DisplayDay(dow: "d\($0)", day_id: $0, ranges: $0 == 1 ? [] : [.init(from: "11:00", to: "21:00")]) }
    }()
    private func et(_ s: String) -> Date {
        let f = DateFormatter(); f.timeZone = OpenStatus.timeZone; f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.date(from: s)!
    }

    func testOpenStatus() {
        // Tuesday 2026-09-08 noon: open until 9 PM
        let noon = OpenStatus.compute(week, now: et("2026-09-08 12:00"))
        XCTAssertTrue(noon.isOpen)
        XCTAssertEqual(noon.label(now: et("2026-09-08 12:00")), "Open · closes 9 PM")
        // 10 PM Tuesday: opens tomorrow
        let late = OpenStatus.compute(week, now: et("2026-09-08 22:00"))
        XCTAssertEqual(late.label(now: et("2026-09-08 22:00")), "Closed · opens tomorrow 11 AM")
        // 9 AM Tuesday: opens today
        XCTAssertEqual(OpenStatus.compute(week, now: et("2026-09-08 09:00")).label(now: et("2026-09-08 09:00")), "Closed · opens today 11 AM")
        // Saturday 10 PM: Sunday closed, so Monday
        XCTAssertEqual(OpenStatus.compute(week, now: et("2026-09-12 22:00")).label(now: et("2026-09-12 22:00")), "Closed · opens Mon 11 AM")
        // Sunday afternoon
        XCTAssertEqual(OpenStatus.compute(week, now: et("2026-09-13 15:00")).label(now: et("2026-09-13 15:00")), "Closed · opens tomorrow 11 AM")
        // Boundary: exactly 21:00 is closed
        XCTAssertFalse(OpenStatus.compute(week, now: et("2026-09-08 21:00")).isOpen)
        // No schedule at all
        XCTAssertEqual(OpenStatus.compute([], now: et("2026-09-08 12:00")).label(), "Closed")
    }

    func testHoursFormatting() {
        XCTAssertEqual(OpenStatus.clockString("11:00"), "11 AM")
        XCTAssertEqual(OpenStatus.clockString("21:00"), "9 PM")
        XCTAssertEqual(OpenStatus.clockString("19:30"), "7:30 PM")
        XCTAssertEqual(OpenStatus.clockString("00:15"), "12:15 AM")
        XCTAssertEqual(OpenStatus.rangeLabel([]), "Closed")
        XCTAssertEqual(HoursSummary.compact(week), "d2 – d7 11 AM – 9 PM · d1 closed")
    }

    func testOrderURLsCarryTheMode() {
        XCTAssertEqual(ChowNow.orderURL(.pickup).absoluteString, "https://direct.chownow.com/order/42710/locations/64455?mode=pickup")
        XCTAssertEqual(ChowNow.orderURL(.delivery).absoluteString, "https://direct.chownow.com/order/42710/locations/64455?mode=delivery&deliversToMe=1")
    }

    func testMoneyAndRules() {
        XCTAssertEqual(7.5.money, "$7.50")
        XCTAssertEqual(125.99.money, "$125.99")
        XCTAssertEqual(Menu.ModifierCategory(id: "a", name: "x", min_qty: 1, max_qty: 1, modifiers: []).rule, "Choose 1")
        XCTAssertEqual(Menu.ModifierCategory(id: "a", name: "x", min_qty: 0, max_qty: 3, modifiers: []).rule, "Optional · up to 3")
        XCTAssertEqual(MenuCatalog.displayName(for: "SANDWICHES & BURGERS"), "Sandwiches & Burgers")
        XCTAssertEqual(MenuCatalog.displayName(for: "Meals under $10"), "Meals under $10")
    }
}
