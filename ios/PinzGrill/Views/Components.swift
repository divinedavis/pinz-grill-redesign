import SwiftUI

enum Brand {
    static let maroon = Color("Brand")
    static let accent = Color("AccentColor")
    static let gold = Color("Gold")
    static let cream = Color("Cream")
    static func headline(_ size: CGFloat) -> Font { .system(size: size, weight: .heavy, design: .default) }
}

/// Uppercase condensed headline, the site's Oswald treatment in a system font.
struct Headline: View {
    let text: String
    var size: CGFloat = 28
    var color: Color = Brand.maroon
    init(_ text: String, size: CGFloat = 28, color: Color = Brand.maroon) { self.text = text; self.size = size; self.color = color }
    var body: some View {
        Text(text.uppercased())
            .font(Brand.headline(size)).kerning(0.5)
            .foregroundStyle(color)
            .lineLimit(2).minimumScaleFactor(0.7)
    }
}

struct PrimaryButton: View {
    let title: String
    var symbol: String? = nil
    var fill: Color = Brand.accent
    var foreground: Color = .white
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let s = symbol { Image(systemName: s) }
                Text(title.uppercased()).kerning(1)
            }
            .font(.system(size: 15, weight: .heavy))
            .frame(maxWidth: .infinity).padding(.vertical, 14)
            .background(fill, in: RoundedRectangle(cornerRadius: 6))
            .foregroundStyle(foreground)
        }
        .buttonStyle(.plain)
    }
}

struct Pill: View {
    let text: String
    var color: Color = Brand.accent
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .heavy)).kerning(1.2)
            .padding(.horizontal, 12).padding(.vertical, 5)
            .background(color, in: Capsule())
            .foregroundStyle(.white)
    }
}

struct StatusPill: View {
    let status: OpenStatus
    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(status.isOpen ? Color.green : Color.red).frame(width: 8, height: 8)
            Text(status.label()).font(.system(size: 13, weight: .bold))
        }
        .padding(.horizontal, 12).padding(.vertical, 7)
        .background(.regularMaterial, in: Capsule())
        .accessibilityIdentifier("status-pill")
    }
}

/// Pickup + Delivery buttons, the pair that appears everywhere ordering starts.
struct OrderButtons: View {
    @EnvironmentObject var order: OrderFlow
    @EnvironmentObject var store: Store
    var idPrefix = "order"

    var body: some View {
        HStack(spacing: 12) {
            PrimaryButton(title: "Pickup", symbol: "bag.fill") { order.start(.pickup) }
                .accessibilityIdentifier("\(idPrefix)-pickup")
            if store.restaurant.offersDelivery {
                PrimaryButton(title: "Delivery", symbol: "car.fill", fill: Brand.maroon) { order.start(.delivery) }
                    .accessibilityIdentifier("\(idPrefix)-delivery")
            }
        }
    }
}

struct SectionCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 12) { content }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Brand.cream, in: RoundedRectangle(cornerRadius: 14))
    }
}

/// Photo for a menu category, from the site's own shots.
enum CategoryArt {
    static func imageName(for category: String) -> String? {
        let n = category.lowercased()
        if n.contains("popular") { return "combo" }
        if n.contains("under") { return "tenders" }
        if n.contains("wing") { return "wings-hot" }
        if n.contains("burger") || n.contains("sandwich") { return "burger" }
        if n.contains("pizza") { return "pizza-cutout" }
        if n.contains("fries") || n.contains("snack") { return "wings-fries" }
        if n.contains("kid") { return "wings-combo-cutout" }
        if n.contains("dog") { return "loaded-fries" }
        return nil
    }
    static func isCutout(_ name: String) -> Bool { name.hasSuffix("cutout") }
}

struct CategoryTile: View {
    let category: Menu.Category
    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle().fill(Brand.cream)
                if let img = CategoryArt.imageName(for: category.name) {
                    if CategoryArt.isCutout(img) {
                        Image(img).resizable().scaledToFit().padding(12)
                    } else {
                        Image(img).resizable().scaledToFill().clipShape(Circle())
                    }
                } else {
                    Image(systemName: "cup.and.saucer.fill").font(.system(size: 44)).foregroundStyle(Brand.maroon)
                }
            }
            .frame(width: 128, height: 128)
            Text(category.name).font(.system(size: 17, weight: .heavy)).foregroundStyle(Brand.maroon)
                .multilineTextAlignment(.center).lineLimit(2)
            Text("\(category.items.count) items").font(.footnote).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct ItemRow: View {
    let item: Menu.Item
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name).font(.system(size: 17, weight: .bold)).foregroundStyle(.primary).multilineTextAlignment(.leading)
                if let d = item.description, !d.isEmpty {
                    Text(d).font(.subheadline).foregroundStyle(.secondary).lineLimit(2).multilineTextAlignment(.leading)
                }
            }
            Spacer(minLength: 8)
            if let p = item.price { Text(p.money).font(.system(size: 16, weight: .semibold)).foregroundStyle(Brand.maroon) }
            if let url = item.imageURL {
                AsyncImage(url: url) { img in img.resizable().scaledToFill() } placeholder: { Color.clear }
                    .frame(width: 64, height: 64).clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}
