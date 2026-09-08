import Foundation
import SwiftUI

/// Where Pinz Grill's orders go. ChowNow has no public ordering API; its
/// hosted checkout at direct.chownow.com is the only supported way to place
/// an order, and it handles pickup vs delivery (ChowNow Flex Delivery via
/// their courier partners) from the `mode` query parameter.
enum OrderMode: String, Identifiable, CaseIterable {
    case pickup, delivery
    var id: String { rawValue }
    var title: String { self == .pickup ? "Pickup" : "Delivery" }
    var symbol: String { self == .pickup ? "bag.fill" : "car.fill" }
}

enum ChowNow {
    static let hqId = "42710"
    static let locationId = "64455"
    static let api = URL(string: "https://api.chownow.com/api")!
    static let ordering = URL(string: "https://direct.chownow.com/order/\(hqId)/locations/\(locationId)")!

    /// direct.chownow.com's bundle reads `deliversToMe=1` to open with Delivery
    /// selected (`mode=` is what the marketplace site uses and is ignored here).
    static func orderURL(_ mode: OrderMode) -> URL {
        var c = URLComponents(url: ordering, resolvingAgainstBaseURL: false)!
        c.queryItems = [URLQueryItem(name: "mode", value: mode.rawValue)]
        if mode == .delivery { c.queryItems?.append(URLQueryItem(name: "deliversToMe", value: "1")) }
        return c.url!
    }
    static let orderHistoryURL = URL(string: "https://direct.chownow.com/order/history")!
}

/// Facts about the business that ChowNow does not carry.
enum Business {
    static let phoneDisplay = "(839) 329-9352"
    static let phoneURL = URL(string: "tel:+18393299352")!
    static let email = "info@pinzgrill.com"
    static let emailURL = URL(string: "mailto:info@pinzgrill.com")!
    static let website = URL(string: "https://www.pinzgrill.com")!
    static let cateringPage = URL(string: "https://www.pinzgrill.com/catering")!
    static let facebook = URL(string: "https://www.facebook.com/people/Pinz-Grill/61581128777867/")!
    static let tiktok = URL(string: "https://www.tiktok.com/@pinzgrill3601a")!
    static let directions = URL(string: "https://maps.apple.com/?daddr=3601+Broad+River+Rd+Unit+A,+Columbia,+SC+29210")!
    static let flavors = ["BBQ", "Jerk", "Hot", "Mild", "Teriyaki", "Teri-Hot", "Lemon Pepper", "Honey Mustard"]
}

@MainActor
final class Store: ObservableObject {
    @Published private(set) var restaurant: Restaurant
    @Published private(set) var catalog: MenuCatalog
    @Published private(set) var isLive = false
    @Published private(set) var lastRefresh: Date?
    @Published private(set) var lastError: String?

    private let offline: Bool
    private static let decoder = JSONDecoder()
    private static let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
    private static let cacheMaxAge: TimeInterval = 7 * 24 * 3600

    init(offline: Bool = CommandLine.arguments.contains("-offline")) {
        self.offline = offline
        // Boot from the freshest local copy so the menu is never blank: last
        // good live fetch if recent, else the snapshot shipped in the bundle.
        let r: Restaurant = Self.cached("restaurant.json") ?? Self.bundled("restaurant")
        let m: Menu = Self.cached("menu.json") ?? Self.bundled("menu")
        restaurant = r
        catalog = MenuCatalog(m)
    }

    /// Fetch both documents; either failing leaves the current data in place.
    func refresh(force: Bool = false) async {
        guard !offline else { return }
        if !force, let t = lastRefresh, Date().timeIntervalSince(t) < 600 { return }
        do {
            async let rData = fetch("restaurant/\(ChowNow.locationId)")
            async let mData = fetch("restaurant/\(ChowNow.locationId)/menu")
            let (rd, md) = try await (rData, mData)
            let r = try Self.decoder.decode(Restaurant.self, from: rd)
            let m = try Self.decoder.decode(Menu.self, from: md)
            restaurant = r; catalog = MenuCatalog(m)
            isLive = true; lastRefresh = Date(); lastError = nil
            Self.write(rd, "restaurant.json"); Self.write(md, "menu.json")
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func fetch(_ path: String) async throws -> Data {
        var req = URLRequest(url: ChowNow.api.appendingPathComponent(path), timeoutInterval: 12)
        req.setValue("PinzGrill-iOS/\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1")", forHTTPHeaderField: "User-Agent")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { throw URLError(.badServerResponse) }
        return data
    }

    private static func bundled<T: Decodable>(_ name: String) -> T {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json"), let data = try? Data(contentsOf: url) else {
            fatalError("\(name).json is not in the app bundle — run scripts/refresh_snapshot.py and check project.yml sources")
        }
        do { return try decoder.decode(T.self, from: data) } catch { fatalError("bundled \(name).json failed to decode: \(error)") }
    }

    private static func cached<T: Decodable>(_ file: String) -> T? {
        let url = cacheDir.appendingPathComponent(file)
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let modified = attrs[.modificationDate] as? Date, Date().timeIntervalSince(modified) < cacheMaxAge,
              let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(T.self, from: data)
    }

    private static func write(_ data: Data, _ file: String) {
        try? data.write(to: cacheDir.appendingPathComponent(file), options: .atomic)
    }
}

/// One presenter for the ChowNow checkout so every "Order" button in the app
/// opens the same in-app Safari sheet (cookies, saved cards and Apple Pay
/// all live there; a WKWebView would lose them).
@MainActor
final class OrderFlow: ObservableObject {
    @Published var active: OrderMode?
    @Published var externalURL: URL?
    func start(_ mode: OrderMode) { active = mode }
}

/// Cross-tab navigation: Home's category tiles land on that section of Menu.
@MainActor
final class Navigation: ObservableObject {
    enum Tab: Hashable { case home, menu, order, info }
    @Published var tab: Tab = .home
    @Published var menuCategoryId: String?

    init() {
        // `-tab menu|order|info` for screenshots and tests.
        if let i = CommandLine.arguments.firstIndex(of: "-tab"), i + 1 < CommandLine.arguments.count {
            switch CommandLine.arguments[i + 1] { case "menu": tab = .menu; case "order": tab = .order; case "info": tab = .info; default: break }
        }
    }
    func showMenu(category: String?) { menuCategoryId = category; tab = .menu }
}
