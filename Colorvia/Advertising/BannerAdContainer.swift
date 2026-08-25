import SwiftUI

/// Collapses completely unless the configured ad service has a renderable banner.
struct BannerAdContainer: View {
  /// When false, no ad request is made (small screens, keyboard, etc.).
  var isEnabled: Bool = true

  /// When true, collapse layout height without tearing down the banner (keyboard).
  var isCollapsed: Bool = false

  @Environment(AdServiceController.self) private var adController
  @Environment(AdEntitlementStore.self) private var entitlementStore
  @State private var didLoadAd = false

  private var canRequest: Bool {
    isEnabled
      && adController.canShowAds
      && !entitlementStore.isAdFree
  }

  var body: some View {
    Group {
      if canRequest && !isCollapsed {
        BannerAdView { loaded in
          withAnimation(.easeOut(duration: 0.2)) {
            didLoadAd = loaded
          }
        }
        .frame(width: 320, height: 50)
        .opacity(didLoadAd ? 1 : 0)
        .frame(maxWidth: .infinity)
        .frame(height: didLoadAd ? 58 : 0)
        .clipped()
        .background(ColorviaTheme.background.opacity(didLoadAd ? 1 : 0))
      }
    }
    .frame(maxWidth: .infinity)
    .accessibilityHidden(!didLoadAd)
  }
}
