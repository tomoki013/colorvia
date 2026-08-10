import SwiftUI

@main
struct ColorviaApp: App {
  @Environment(\.scenePhase) private var scenePhase
  @State private var appState = AppState()
  @State private var adController = AdServiceController.shared
  @State private var entitlementStore = AdEntitlementStore.shared
  @State private var purchaseManager = PurchaseManager.shared

  var body: some Scene {
    WindowGroup {
      RootView()
        .environment(appState)
        .environment(adController)
        .environment(entitlementStore)
        .environment(purchaseManager)
        .preferredColorScheme(appState.appearance.colorScheme)
        .task { await appState.load() }
        .task { await purchaseManager.start() }
        .task(id: scenePhase) {
          guard scenePhase == .active else { return }
          await adController.prepare()
        }
    }
  }
}
