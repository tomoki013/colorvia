import SwiftUI

@main
struct ColorviaApp: App {
  @Environment(\.scenePhase) private var scenePhase
  @State private var appState = AppState()
  @State private var adController = AdServiceController.shared
  @State private var entitlementStore = AdEntitlementStore.shared

  var body: some Scene {
    WindowGroup {
      RootView()
        .environment(appState)
        .environment(adController)
        .environment(entitlementStore)
        .preferredColorScheme(appState.appearance.colorScheme)
        .task { await appState.load() }
        .task(id: scenePhase) {
          guard scenePhase == .active else { return }
          await adController.prepare()
        }
    }
  }
}
