import SwiftUI

/// Shows a fixed 320×50 banner only when consent allows, the user is not ad-free,
/// the layout has room, and the ad has loaded successfully.
struct BannerAdContainer: View {
  /// When false, no ad request is made (small screens, keyboard, etc.).
  var isEnabled: Bool = true

  /// When true, collapse layout height without tearing down the banner (keyboard).
  var isCollapsed: Bool = false

  @Environment(AdMobConsentManager.self) private var consentManager
  @Environment(AdEntitlementStore.self) private var entitlementStore

  @State private var didLoadAd = false

  private var canRequest: Bool {
    isEnabled
      && consentManager.canRequestAds
      && !entitlementStore.isAdFree
  }

  private var isVisible: Bool {
    canRequest && didLoadAd && !isCollapsed
  }

  var body: some View {
    Group {
      if canRequest {
        BannerAdView { loaded in
          withAnimation(.easeOut(duration: 0.2)) {
            didLoadAd = loaded
          }
        }
        .frame(
          width: isVisible ? 320 : 0,
          height: isVisible ? 50 : 0
        )
        .opacity(isVisible ? 1 : 0)
        .clipped()
        .accessibilityHidden(!isVisible)
        .frame(maxWidth: .infinity)
        .padding(.top, isVisible ? 8 : 0)
        .padding(.bottom, isVisible ? 4 : 0)
        .background(ColorviaTheme.background.opacity(isVisible ? 1 : 0))
      }
    }
    .frame(maxWidth: .infinity)
    .animation(.easeOut(duration: 0.2), value: isVisible)
  }
}
