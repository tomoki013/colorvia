import SwiftUI

@main
struct ColorviaApp: App {
  @State private var appState = AppState()

  var body: some Scene {
    WindowGroup {
      RootView()
        .environment(appState)
        .preferredColorScheme(appState.appearance.colorScheme)
        .task { await appState.load() }
    }
  }
}
