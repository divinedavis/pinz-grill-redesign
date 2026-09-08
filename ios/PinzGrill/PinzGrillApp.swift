import SwiftUI

@main
struct PinzGrillApp: App {
    @StateObject private var store = Store()
    @StateObject private var order = OrderFlow()
    @StateObject private var nav = Navigation()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(order)
                .environmentObject(nav)
                .tint(Color("Brand"))
                .task { await store.refresh() }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { Task { await store.refresh() } }
                }
        }
    }
}
