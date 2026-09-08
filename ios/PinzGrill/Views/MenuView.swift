import SwiftUI

struct MenuView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var nav: Navigation
    @State private var query = ""
    @State private var selected: Menu.Item?

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0, pinnedViews: []) {
                        // 24pt of dead space under the bar: iOS 26's scroll-edge region eats the first taps.
                        Color.clear.frame(height: 24)
                        if query.isEmpty { chips(proxy) }
                        ForEach(store.catalog.search(query), id: \.category.id) { entry in
                            section(entry.category, items: entry.items)
                        }
                        if store.catalog.search(query).isEmpty {
                            Text("Nothing on the menu matches \"\(query)\".").foregroundStyle(.secondary).padding(24)
                        }
                        footer
                    }
                }
                .onChange(of: nav.menuCategoryId) { _, id in
                    guard let id else { return }
                    withAnimation { proxy.scrollTo(id, anchor: .top) }
                    nav.menuCategoryId = nil
                }
                .onAppear {
                    if let id = nav.menuCategoryId { proxy.scrollTo(id, anchor: .top); nav.menuCategoryId = nil }
                }
            }
            .navigationTitle("Menu")
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search wings, pizza, combos…")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if store.isLive { Text("LIVE").font(.caption2.weight(.heavy)).foregroundStyle(.green).accessibilityIdentifier("menu-live") }
                }
            }
            .refreshable { await store.refresh(force: true) }
            .sheet(item: $selected) { ItemDetailView(item: $0) }
        }
    }

    private func chips(_ proxy: ScrollViewProxy) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(store.catalog.categories) { cat in
                    Button(cat.name) { withAnimation { proxy.scrollTo(cat.id, anchor: .top) } }
                        .font(.footnote.weight(.heavy))
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(Brand.cream, in: Capsule()).foregroundStyle(Brand.maroon)
                        .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 8)
    }

    private func section(_ cat: Menu.Category, items: [Menu.Item]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Headline(cat.name, size: 24).padding(.horizontal, 16).padding(.top, 22).padding(.bottom, 6).id(cat.id)
            ForEach(items) { item in
                Button { selected = item } label: { ItemRow(item: item).padding(.horizontal, 16) }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("menu-item")
                Divider().padding(.leading, 16)
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 6) {
            Text("Prices and availability come from Pinz Grill's online ordering and can differ from the in-store board.")
            if let t = store.lastRefresh { Text("Updated \(t.formatted(date: .omitted, time: .shortened))") }
            else if let e = store.lastError { Text("Showing the last saved menu · \(e)") }
        }
        .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
        .frame(maxWidth: .infinity).padding(24)
    }
}

struct ItemDetailView: View {
    let item: Menu.Item
    @EnvironmentObject var store: Store
    @EnvironmentObject var order: OrderFlow
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if let url = item.imageURL {
                        AsyncImage(url: url) { $0.resizable().scaledToFill() } placeholder: { Brand.cream }
                            .frame(height: 220).frame(maxWidth: .infinity).clipped()
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text(item.name).font(.title2.weight(.heavy)).foregroundStyle(Brand.maroon)
                        if let p = item.price { Text(p.money).font(.title3.weight(.semibold)) }
                        if let d = item.description, !d.isEmpty { Text(d).foregroundStyle(.secondary) }
                    }
                    .padding(.horizontal, 20)

                    let groups = store.catalog.modifierGroups(for: item)
                    if !groups.isEmpty {
                        VStack(alignment: .leading, spacing: 14) {
                            ForEach(groups, id: \.group.id) { g in
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text(g.group.name).font(.headline)
                                        Spacer()
                                        Text(g.group.rule).font(.caption.weight(.bold)).foregroundStyle(g.group.isRequired ? Brand.accent : .secondary)
                                    }
                                    ForEach(g.options) { m in
                                        HStack {
                                            Text(m.name).font(.subheadline)
                                            Spacer()
                                            if let p = m.price, p > 0 { Text("+\(p.money)").font(.subheadline).foregroundStyle(.secondary) }
                                        }
                                        .padding(.vertical, 3)
                                    }
                                }
                                .padding(14).background(Brand.cream, in: RoundedRectangle(cornerRadius: 10))
                            }
                        }
                        .padding(.horizontal, 20)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Customize and pay on Pinz Grill's secure checkout. Choose pickup or delivery to start your order.")
                            .font(.footnote).foregroundStyle(.secondary)
                        OrderButtons(idPrefix: "item-order")
                    }
                    .padding(20)
                }
                .padding(.bottom, 20)
            }
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
        .presentationDragIndicator(.visible)
    }
}
