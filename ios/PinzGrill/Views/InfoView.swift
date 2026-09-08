import SwiftUI

struct InfoView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var order: OrderFlow

    private var version: String {
        let d = Bundle.main.infoDictionary
        return "\(d?["CFBundleShortVersionString"] as? String ?? "1.0") (\(d?["CFBundleVersion"] as? String ?? "1"))"
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Location") {
                    if let a = store.restaurant.address {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(a.line1).font(.headline).accessibilityIdentifier("info-address")
                            Text(a.line2).foregroundStyle(Brand.ink.opacity(0.65))
                        }
                    }
                    Link(destination: Business.directions) { Label("Directions", systemImage: "location.fill") }
                    Link(destination: Business.phoneURL) { Label("Call \(Business.phoneDisplay)", systemImage: "phone.fill") }
                    Link(destination: Business.emailURL) { Label(Business.email, systemImage: "envelope.fill") }
                    Link(destination: Business.website) { Label("pinzgrill.com", systemImage: "safari.fill") }
                }
                hours("Pickup hours", store.restaurant.pickup?.hours ?? [])
                if store.restaurant.offersDelivery { hours("Delivery hours", store.restaurant.delivery?.hours ?? []) }
                Section("Catering") {
                    Text("Wings, tenders, burgers, pizza and sides for 10 to 200 people, cooked fresh for your event. Wing packages from 30 to 100 with up to five sauces.")
                        .font(.subheadline)
                    Link(destination: Business.phoneURL) { Label("Call to book", systemImage: "phone.fill") }
                    Button { order.externalURL = Business.cateringPage } label: { Label("Catering details", systemImage: "fork.knife") }
                }
                Section("Follow") {
                    Link(destination: Business.facebook) { Label("Facebook", systemImage: "hand.thumbsup.fill") }
                    Link(destination: Business.tiktok) { Label("TikTok", systemImage: "music.note") }
                }
                Section("About") {
                    Text("Made to order on Broad River Road. Wings sauced eight ways, burgers, patty melts, jumbo dogs, pizza and more.").font(.subheadline)
                    LabeledContent("Online ordering", value: "ChowNow")
                    LabeledContent("Menu source", value: store.isLive ? "Live" : "Saved copy")
                    LabeledContent("Version", value: version)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.white)
            .foregroundStyle(Brand.ink)
            .navigationTitle("Pinz Grill")
        }
    }

    private func hours(_ title: String, _ days: [Restaurant.DisplayDay]) -> some View {
        let ordered = days.sorted { ($0.day_id == 1 ? 8 : $0.day_id) < ($1.day_id == 1 ? 8 : $1.day_id) }
        return Section(title) {
            ForEach(ordered, id: \.day_id) { d in
                LabeledContent(d.dow, value: OpenStatus.rangeLabel(d.ranges)).font(.subheadline)
            }
        }
    }
}
