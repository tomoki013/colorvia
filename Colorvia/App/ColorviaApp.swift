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
        .task {
          await appState.load()
          await purchaseManager.start()
          // Applied last so it wins over whatever real entitlement state
          // `purchaseManager.start()` just resolved (none, in a simulator).
          if ScreenshotMode.isEnabled {
            await ScreenshotMode.apply(to: appState)
          }
        }
        .task(id: scenePhase) {
          guard scenePhase == .active else { return }
          await adController.prepare()
        }
    }
  }
}

/// Drives the app into a state worth capturing for App Store / brand-site
/// screenshots: ad-free (no AdMob test creative), and a representative set
/// of visited countries instead of the empty first-run state.
///
/// Launch with `-ScreenshotMode` plus one of:
///   `-ScreenshotVariant coral` — coral map colour theme
///   `-ScreenshotVariant dark`  — forced dark appearance
/// Any other (or no) variant leaves the default teal / system appearance.
enum ScreenshotMode {
  static var isEnabled: Bool {
    ProcessInfo.processInfo.arguments.contains("-ScreenshotMode")
  }

  private static var variant: String? {
    let args = ProcessInfo.processInfo.arguments
    guard let index = args.firstIndex(of: "-ScreenshotVariant"), index + 1 < args.count else {
      return nil
    }
    return args[index + 1]
  }

  /// Country code to land HomeView's NavigationStack on directly, e.g. `JP`
  /// to open Japan's SubdivisionMapScreen instead of the world map — lets
  /// screenshot capture reach a screen no amount of launch-time seeding can
  /// put you on without an actual tap.
  static var subdivisionCountryCode: String? {
    let args = ProcessInfo.processInfo.arguments
    guard let index = args.firstIndex(of: "-ScreenshotSubdivision"), index + 1 < args.count else {
      return nil
    }
    return args[index + 1]
  }

  /// A representative spread across continents so the map and statistics
  /// screens both look genuinely used rather than empty.
  private static let demoVisitedCountries: Set<String> = [
    "JP", "KR", "TH", "US", "FR", "IT", "GB", "DE", "ES", "AU", "CA", "BR",
  ]

  @MainActor
  static func apply(to appState: AppState) async {
    AdEntitlementStore.shared.applyPurchaseState(true)
    if appState.hasCompletedOnboarding {
      await appState.replaceVisitedCountries(with: demoVisitedCountries)
    } else {
      // Also marks onboarding complete, so RootView shows HomeView instead
      // of stalling on the first-run flow.
      await appState.completeOnboarding(with: demoVisitedCountries)
    }
    // Explicit in every branch (not just "coral") so a colour choice
    // persisted from an earlier screenshot launch never bleeds into this one.
    appState.setMapColor(variant == "coral" ? .coral : .teal)
    appState.setAppearance(variant == "dark" ? .dark : .light)

    // A capture of Japan's SubdivisionMapScreen with only the seed onboarding
    // ran through — 3 of 47 prefectures — reads as barely used. Fill in a
    // representative spread (roughly every third prefecture) so the map
    // actually looks like a travelled country.
    if subdivisionCountryCode == "JP" {
      let spread = Set(
        appState.prefectures.enumerated().filter { $0.offset % 3 == 0 }.map(\.element.id)
      )
      await appState.replaceVisitedPrefectures(with: spread)
    }
  }
}
