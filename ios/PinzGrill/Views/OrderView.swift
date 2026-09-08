import SwiftUI

struct OrderView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var order: OrderFlow

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Color.clear.frame(height: 8)
                    if let p = store.restaurant.pickup { modeCard(.pickup, p) }
                    if store.restaurant.offersDelivery, let d = store.restaurant.delivery { modeCard(.delivery, d) }
                    else { noDelivery }
                    notes
                }
                .padding(16)
            }
            .navigationTitle("Order")
            .refreshable { await store.refresh(force: true) }
        }
    }

    private func modeCard(_ mode: OrderMode, _ f: Restaurant.Fulfillment) -> some View {
        let status = OpenStatus.compute(f.hours)
        let paused = store.isLive && status.isOpen && f.is_available_now == false
        return SectionCard {
            HStack(spacing: 12) {
                Image(systemName: mode.symbol).font(.title2).foregroundStyle(.white).frame(width: 48, height: 48)
                    .background(mode == .pickup ? Brand.accent : Brand.maroon, in: RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 2) {
                    Headline(mode.title, size: 24)
                    Text(paused ? "Paused right now · try again shortly" : status.label())
                        .font(.subheadline.weight(.semibold)).foregroundStyle(paused ? Brand.accent : (status.isOpen ? .green : .secondary))
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                if mode == .delivery {
                    if let fee = f.deliveryFee { detail("Delivery fee", fee.money) }
                    if let min = f.deliveryMinimum { detail("Minimum order", min.money) }
                    detail("Delivered by", "Pinz Grill's ChowNow courier partners")
                } else {
                    detail("Where", store.restaurant.address?.line1 ?? "3601 Broad River Rd")
                    if let min = f.min_order_amt, min > 1 { detail("Minimum order", min.money) }
                }
                if let lead = f.order_ahead?.min_lead_time { detail("Order ahead", "as little as \(lead) min out") }
                detail("Today", todayLabel(f.hours))
            }
            PrimaryButton(title: "Start \(mode.title) order", symbol: mode.symbol, fill: mode == .pickup ? Brand.accent : Brand.maroon) { order.start(mode) }
                .accessibilityIdentifier("order-tab-\(mode.rawValue)")
            if !status.isOpen {
                Text("You can still place an order ahead for the next open window.").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var noDelivery: some View {
        SectionCard {
            Headline("Delivery", size: 24)
            Text("Delivery isn't available from this location right now. Pickup orders are ready in minutes.").font(.subheadline).foregroundStyle(.secondary)
        }
    }

    private var notes: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let lo = store.restaurant.large_order, let amt = lo.amount, let lead = lo.min_lead_time {
                Label("Orders over \(amt.money) need \(lead) minutes' notice.", systemImage: "clock.fill")
            }
            Label { Text("Rather call it in? ") + Text(Business.phoneDisplay).bold() } icon: { Image(systemName: "phone.fill") }
                .onTapGesture { UIApplication.shared.open(Business.phoneURL) }
            Button { order.externalURL = ChowNow.orderHistoryURL } label: {
                Label("Past orders & account", systemImage: "clock.arrow.circlepath")
            }
            Text("Checkout runs on ChowNow, the same commission-free system behind pinzgrill.com, so every dollar goes to the restaurant instead of a delivery marketplace.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .font(.subheadline)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
    }

    private func detail(_ k: String, _ v: String) -> some View {
        HStack(alignment: .top) {
            Text(k).foregroundStyle(.secondary).frame(width: 118, alignment: .leading)
            Text(v).fontWeight(.semibold)
        }
        .font(.subheadline)
    }

    private func todayLabel(_ days: [Restaurant.DisplayDay]) -> String {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = OpenStatus.timeZone
        let wd = cal.component(.weekday, from: Date())
        return OpenStatus.rangeLabel(days.first { $0.day_id == wd }?.ranges ?? [])
    }
}
