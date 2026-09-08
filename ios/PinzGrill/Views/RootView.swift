import SwiftUI

struct RootView: View {
    @EnvironmentObject var nav: Navigation
    @EnvironmentObject var order: OrderFlow

    var body: some View {
        TabView(selection: $nav.tab) {
            HomeView().tabItem { Label("Home", systemImage: "flame.fill") }.tag(Navigation.Tab.home)
            MenuView().tabItem { Label("Menu", systemImage: "fork.knife") }.tag(Navigation.Tab.menu)
            OrderView().tabItem { Label("Order", systemImage: "bag.fill") }.tag(Navigation.Tab.order)
            InfoView().tabItem { Label("Info", systemImage: "info.circle.fill") }.tag(Navigation.Tab.info)
        }
        .fullScreenCover(item: $order.active) { mode in
            SafariView(url: ChowNow.orderURL(mode)) { order.active = nil }
                .ignoresSafeArea()
        }
        .sheet(item: $order.externalURL) { url in
            SafariView(url: url) { order.externalURL = nil }
                .ignoresSafeArea()
        }
    }
}

extension URL: Identifiable { public var id: String { absoluteString } }
