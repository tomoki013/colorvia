import SwiftUI

struct RootView: View {
  @Environment(AppState.self) private var appState

  var body: some View {
    Group {
      if appState.isLoading {
        LaunchView()
      } else if appState.hasCompletedOnboarding {
        HomeView()
      } else {
        OnboardingView()
      }
    }
    .animation(.easeInOut(duration: 0.35), value: appState.hasCompletedOnboarding)
  }
}

private struct LaunchView: View {
  var body: some View {
    ZStack {
      ColorviaTheme.background.ignoresSafeArea()
      Text("Colorvia")
        .font(ColorviaTheme.logoFont(size: 42))
        .foregroundStyle(ColorviaTheme.ink)
    }
  }
}
