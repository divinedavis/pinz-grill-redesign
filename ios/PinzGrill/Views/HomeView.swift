import SwiftUI

struct HomeView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var order: OrderFlow
    @EnvironmentObject var nav: Navigation
    @State private var selected: Menu.Item?

    private var status: OpenStatus { OpenStatus.compute(store.restaurant.pickup?.hours ?? []) }
    private let columns = [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    hero
                    deals.padding(.horizontal, 16).padding(.top, 20)
                    categories.padding(.horizontal, 16).padding(.top, 28)
                    favorites.padding(.top, 28)
                    findUs.padding(.horizontal, 16).padding(.vertical, 28)
                }
            }
            .background(Color.white)
            .toolbar(.hidden, for: .navigationBar)
            .refreshable { await store.refresh(force: true) }
            .sheet(item: $selected) { ItemDetailView(item: $0) }
        }
    }

    private var hero: some View {
        ZStack(alignment: .bottom) {
            // Color.clear takes the proposed width; a bare scaledToFill image
            // reports its own and stretches the whole ScrollView past the screen.
            Color.clear.frame(height: 440)
                .overlay { Image("hero-wings").resizable().scaledToFill() }
                .clipped()
            LinearGradient(colors: [.black.opacity(0.15), .black.opacity(0.75)], startPoint: .top, endPoint: .bottom)
            VStack(spacing: 14) {
                Image("logo").resizable().scaledToFit().frame(height: 96)
                    .accessibilityLabel("Pinz Grill")
                Headline("Wings. Burgers. Patty Melts.", size: 32, color: .white)
                    .multilineTextAlignment(.center).shadow(radius: 6)
                Text("Hot off the grill on Broad River Road. Sauced your way, ready when you pull up.")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(.white.opacity(0.92))
                    .multilineTextAlignment(.center).padding(.horizontal, 24)
                StatusPill(status: status)
                OrderButtons(idPrefix: "home-order").padding(.horizontal, 20).padding(.top, 4)
            }
            .padding(.bottom, 24)
        }
        .frame(height: 440)
        .ignoresSafeArea(edges: .top)
    }

    private var deals: some View {
        let r = store.restaurant
        return SectionCard {
            HStack(spacing: 10) {
                Image(systemName: "flame.fill").foregroundStyle(.white).padding(10).background(Brand.accent, in: Circle())
                Headline("Deals & rewards", size: 22)
            }
            ForEach(r.discounts) { d in
                VStack(alignment: .leading, spacing: 2) {
                    Text(d.short_description ?? "Discount").font(.headline).foregroundStyle(Brand.ink)
                    Text([d.long_description, d.type == "automatic" ? "Applied automatically at checkout." : nil].compactMap { $0 }.joined(separator: " "))
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            }
            if r.rewards?.enabled == true, let m = r.rewards?.messages {
                Divider()
                VStack(alignment: .leading, spacing: 2) {
                    Text(m.program_description ?? "Rewards").font(.headline).foregroundStyle(Brand.ink)
                    if let t = m.learn_more_title { Text(t).font(.subheadline).foregroundStyle(.secondary) }
                    if let d = m.learn_more_description { Text(d).font(.subheadline).foregroundStyle(.secondary) }
                }
            }
            if r.discounts.isEmpty && r.rewards?.enabled != true {
                Text("Order online for pickup or delivery through Pinz Grill's own checkout.").font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }

    private var categories: some View {
        VStack(alignment: .leading, spacing: 16) {
            Headline("Order by category")
            LazyVGrid(columns: columns, spacing: 24) {
                ForEach(store.catalog.categories) { cat in
                    Button { nav.showMenu(category: cat.id) } label: { CategoryTile(category: cat) }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("home-category")
                }
            }
        }
    }

    private var favorites: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Headline("Fan favorites")
                Spacer()
                Button("Full menu") { nav.showMenu(category: nil) }.font(.subheadline.weight(.bold))
            }
            .padding(.horizontal, 16)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(store.catalog.popular) { item in
                        Button { selected = item } label: { FavoriteCard(item: item) }.buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
            flavors.padding(.horizontal, 16)
        }
    }

    private var flavors: some View {
        SectionCard {
            Headline("Sauced 8 ways", size: 22)
            Text("Every wing and tender gets tossed to order. Pick one, or mix it up on a party pack.").font(.subheadline).foregroundStyle(.secondary)
            FlowChips(items: Business.flavors)
        }
    }

    private var findUs: some View {
        let r = store.restaurant
        return VStack(alignment: .leading, spacing: 14) {
            Headline("Find us", size: 26)
            if let a = r.address {
                Text("\(a.line1)\n\(a.line2)").font(.body.weight(.semibold)).foregroundStyle(Brand.ink)
            }
            HStack(alignment: .top, spacing: 24) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("HOURS").font(.caption.weight(.heavy)).foregroundStyle(Brand.ink.opacity(0.6))
                    Text(HoursSummary.compact(r.pickup?.hours ?? [])).font(.subheadline).foregroundStyle(Brand.ink)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("CALL").font(.caption.weight(.heavy)).foregroundStyle(Brand.ink.opacity(0.6))
                    Link(Business.phoneDisplay, destination: Business.phoneURL).font(.subheadline).foregroundStyle(Brand.ink)
                }
            }
            HStack(spacing: 12) {
                Link(destination: Business.directions) {
                    Label("Directions", systemImage: "location.fill").font(.subheadline.weight(.heavy))
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(Brand.maroon, in: RoundedRectangle(cornerRadius: 6)).foregroundStyle(.white)
                }
                Link(destination: Business.phoneURL) {
                    Label("Call", systemImage: "phone.fill").font(.subheadline.weight(.heavy))
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(Brand.accent, in: RoundedRectangle(cornerRadius: 6)).foregroundStyle(.white)
                }
            }
        }
        .padding(20)
        .background(.white, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Brand.line, lineWidth: 1))
    }
}

struct FavoriteCard: View {
    let item: Menu.Item
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(.white)
                if let url = item.imageURL {
                    AsyncImage(url: url) { $0.resizable().scaledToFill() } placeholder: { fallback }
                } else { fallback }
            }
            .frame(width: 200, height: 140).clipShape(RoundedRectangle(cornerRadius: 12))
            Text(item.name).font(.headline).foregroundStyle(Brand.ink).lineLimit(2).multilineTextAlignment(.leading)
            if let p = item.price { Text(p.money).font(.subheadline.weight(.bold)).foregroundStyle(Brand.ink) }
        }
        .frame(width: 200, alignment: .leading)
    }
    private var fallback: some View {
        Image(CategoryArt.imageName(for: item.name) ?? "combo").resizable().scaledToFill()
    }
}

struct FlowChips: View {
    let items: [String]
    var body: some View {
        // Two rows of chips; simpler and more predictable than a Layout for 8 short words.
        let half = (items.count + 1) / 2
        VStack(alignment: .leading, spacing: 8) {
            ForEach([Array(items.prefix(half)), Array(items.dropFirst(half))], id: \.self) { row in
                HStack(spacing: 8) {
                    ForEach(row, id: \.self) { f in
                        Text(f).font(.caption.weight(.heavy)).padding(.horizontal, 10).padding(.vertical, 6)
                            .background(Brand.maroon, in: Capsule()).foregroundStyle(.white)
                    }
                }
            }
        }
    }
}

enum HoursSummary {
    /// "Mon – Sat 11 AM – 9 PM · Sun closed": collapses identical consecutive days.
    static func compact(_ days: [Restaurant.DisplayDay]) -> String {
        let ordered = days.sorted { ($0.day_id == 1 ? 8 : $0.day_id) < ($1.day_id == 1 ? 8 : $1.day_id) }   // Mon…Sun
        var groups: [(first: String, last: String, label: String)] = []
        for d in ordered {
            let label = OpenStatus.rangeLabel(d.ranges), short = String(d.dow.prefix(3))
            if let last = groups.last, last.label == label { groups[groups.count - 1].last = short }
            else { groups.append((short, short, label)) }
        }
        return groups.map { g in
            let span = g.first == g.last ? g.first : "\(g.first) – \(g.last)"
            return "\(span) \(g.label == "Closed" ? "closed" : g.label)"
        }.joined(separator: " · ")
    }
}
