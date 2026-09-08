import Foundation

// Decodable subsets of the two documents ChowNow's own ordering page reads
// from api.chownow.com. Every field is optional except the ones the UI
// cannot render without, so a schema change on their side degrades a
// section instead of failing the whole decode.

struct Restaurant: Decodable {
    struct Address: Decodable {
        let street_address1: String?
        let street_address2: String?
        let city: String?
        let state: String?
        let zip: String?
        let latitude: Double?
        let longitude: Double?

        var line1: String {
            [street_address1, street_address2].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")
        }
        var line2: String { "\(city ?? ""), \(state ?? "") \(zip ?? "")" }
        var oneLine: String { "\(line1), \(line2)" }
    }

    struct TimeRange: Decodable, Equatable {
        let from: String   // "11:00"
        let to: String     // "21:00"
    }

    /// One weekday of the schedule ChowNow shows diners. `day_id` is 1 = Sunday … 7 = Saturday,
    /// the same numbering as Foundation's `Calendar.Component.weekday`.
    struct DisplayDay: Decodable {
        let dow: String
        let day_id: Int
        let ranges: [TimeRange]
    }

    struct DeliveryRange: Decodable {
        let delivery_charge: Double?
        let delivery_charge_type: String?
        let min_order_amt: Double?
        let max_order_amt: Double?
    }

    struct OrderAhead: Decodable { let min_lead_time: Int? }

    struct Fulfillment: Decodable {
        let is_available_now: Bool?
        let next_available_time: String?
        let display_hours: [DisplayDay]?
        let min_order_amt: Double?
        let delivery_ranges: [DeliveryRange]?
        let order_ahead: OrderAhead?

        var hours: [DisplayDay] { display_hours ?? [] }
        var deliveryFee: Double? { delivery_ranges?.first?.delivery_charge }
        var deliveryMinimum: Double? { delivery_ranges?.first?.min_order_amt }
    }

    struct Fulfillments: Decodable {
        let pickup: Fulfillment?
        let delivery: Fulfillment?
        let curbside: Fulfillment?
        let dine_in: Fulfillment?
    }

    struct Discount: Decodable, Identifiable {
        let id: String
        let short_description: String?
        let long_description: String?
        let type: String?
    }

    struct Rewards: Decodable {
        struct Messages: Decodable {
            let program_description: String?
            let learn_more_title: String?
            let learn_more_description: String?
        }
        let enabled: Bool?
        let messages: Messages?
    }

    struct LargeOrder: Decodable {
        let min_lead_time: Int?
        let amount: Double?
    }

    struct Media: Decodable {
        let cover_image_url: String?
        let logo_image_url: String?
    }

    let id: String
    let name: String?
    let short_name: String?
    let phone: String?
    let address: Address?
    let fulfillment: Fulfillments?
    let available_discounts: [Discount]?
    let rewards: Rewards?
    let is_live: Bool?
    let is_busy: Bool?
    let website_url: String?
    let tax_rate: Double?
    let large_order: LargeOrder?
    let primary_cuisine: String?
    let media: Media?

    var displayName: String { short_name ?? name ?? "Pinz Grill" }
    var pickup: Fulfillment? { fulfillment?.pickup }
    var delivery: Fulfillment? { fulfillment?.delivery }
    /// Delivery is offered at all (hours configured), whether or not it is on right now.
    var offersDelivery: Bool { !(delivery?.hours.isEmpty ?? true) }
    var discounts: [Discount] { available_discounts ?? [] }
}

struct Menu: Decodable {
    struct Image: Decodable { let cropped_url: String? }

    struct Item: Decodable, Identifiable, Hashable {
        let id: String
        let name: String
        let description: String?
        let price: Double?
        let image: Image?
        let modifier_categories: [String]?

        var imageURL: URL? { image?.cropped_url.flatMap(URL.init(string:)) }
        var modifierCategoryIds: [String] { modifier_categories ?? [] }
        static func == (a: Item, b: Item) -> Bool { a.id == b.id }
        func hash(into h: inout Hasher) { h.combine(id) }
    }

    struct Category: Decodable, Identifiable {
        let id: String
        let name: String
        let items: [Item]
    }

    struct ModifierCategory: Decodable, Identifiable {
        let id: String
        let name: String
        let min_qty: Int?
        let max_qty: Int?
        let modifiers: [String]

        var isRequired: Bool { (min_qty ?? 0) > 0 }
        var rule: String {
            let min = min_qty ?? 0, max = max_qty ?? 0
            if min > 0 && max == min { return min == 1 ? "Choose 1" : "Choose \(min)" }
            if min > 0 { return "Choose at least \(min)" }
            if max == 1 { return "Optional · pick 1" }
            if max > 1 { return "Optional · up to \(max)" }
            return "Optional"
        }
    }

    struct Modifier: Decodable, Identifiable {
        let id: String
        let name: String
        let price: Double?
        let is_default: Bool?
    }

    let id: String?
    let menu_categories: [Category]
    let modifier_categories: [ModifierCategory]
    let modifiers: [Modifier]
}

/// The menu shaped for display: Toast pushes a few oddities through ChowNow
/// (the same "Meals under $10" category twice, drink sizes as bare "Small" /
/// "Large" categories) that would read as bugs in the app.
struct MenuCatalog {
    let categories: [Menu.Category]
    private let modifierCategoriesById: [String: Menu.ModifierCategory]
    private let modifiersById: [String: Menu.Modifier]

    init(_ menu: Menu) {
        var seen = Set<String>()
        categories = menu.menu_categories.compactMap { cat in
            let name = Self.displayName(for: cat.name)
            guard !cat.items.isEmpty, seen.insert(name.lowercased()).inserted else { return nil }
            return Menu.Category(id: cat.id, name: name, items: cat.items)
        }
        modifierCategoriesById = Dictionary(menu.modifier_categories.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        modifiersById = Dictionary(menu.modifiers.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
    }

    static func displayName(for raw: String) -> String {
        let t = raw.trimmingCharacters(in: .whitespaces)
        switch t.lowercased() {
        case "small": return "Drinks · Small"
        case "large": return "Drinks · Large"
        default: return t.uppercased() == t ? t.capitalized : t
        }
    }

    var popular: [Menu.Item] {
        categories.first { $0.name.lowercased().contains("popular") }?.items ?? Array(allItems.prefix(6))
    }
    var allItems: [Menu.Item] { categories.flatMap(\.items) }

    func modifierGroups(for item: Menu.Item) -> [(group: Menu.ModifierCategory, options: [Menu.Modifier])] {
        item.modifierCategoryIds.compactMap { id in
            guard let g = modifierCategoriesById[id] else { return nil }
            return (g, g.modifiers.compactMap { modifiersById[$0] })
        }
    }

    func search(_ query: String) -> [(category: Menu.Category, items: [Menu.Item])] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return categories.map { ($0, $0.items) } }
        return categories.compactMap { cat in
            let hits = cat.items.filter { $0.name.lowercased().contains(q) || ($0.description ?? "").lowercased().contains(q) }
            return hits.isEmpty ? nil : (cat, hits)
        }
    }
}

extension Double {
    var money: String {
        let f = NumberFormatter(); f.numberStyle = .currency; f.currencyCode = "USD"; f.locale = Locale(identifier: "en_US")
        return f.string(from: NSNumber(value: self)) ?? String(format: "$%.2f", self)
    }
}
