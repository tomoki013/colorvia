import SwiftUI

@main
struct ColorviaApp: App {
  @State private var appState = AppState()
  @State private var consentManager = AdMobConsentManager.shared
  @State private var entitlementStore = AdEntitlementStore.shared

  var body: some Scene {
    WindowGroup {
      RootView()
        .environment(appState)
        .environment(consentManager)
        .environment(entitlementStore)
        .preferredColorScheme(appState.appearance.colorScheme)
        .task { await appState.load() }
        .task { await consentManager.prepare() }
    }
  }
}
