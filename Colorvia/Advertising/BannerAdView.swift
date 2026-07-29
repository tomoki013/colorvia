import GoogleMobileAds
import SwiftUI
import UIKit

/// UIKit banner wrapper. Loads once; does not reload in `updateUIView`.
struct BannerAdView: UIViewRepresentable {
  let onLoadStateChanged: (Bool) -> Void

  func makeCoordinator() -> Coordinator {
    Coordinator(onLoadStateChanged: onLoadStateChanged)
  }

  func makeUIView(context: Context) -> BannerView {
    let bannerView = BannerView(adSize: AdSizeBanner)
    bannerView.adUnitID = AdMobConfiguration.bannerAdUnitID
    bannerView.delegate = context.coordinator
    bannerView.rootViewController = Self.presentingViewController()
    bannerView.backgroundColor = .clear

    let unitID = AdMobConfiguration.bannerAdUnitID
    if unitID.isEmpty {
      DispatchQueue.main.async {
        onLoadStateChanged(false)
      }
    } else {
      bannerView.load(Request())
    }

    return bannerView
  }

  func updateUIView(_ uiView: BannerView, context: Context) {
    if uiView.rootViewController == nil {
      uiView.rootViewController = Self.presentingViewController()
    }
  }

  private static func presentingViewController() -> UIViewController? {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    let window =
      scenes
      .flatMap(\.windows)
      .first(where: \.isKeyWindow) ?? scenes.first?.windows.first
    return window?.rootViewController
  }

  final class Coordinator: NSObject, BannerViewDelegate {
    private let onLoadStateChanged: (Bool) -> Void

    init(onLoadStateChanged: @escaping (Bool) -> Void) {
      self.onLoadStateChanged = onLoadStateChanged
    }

    func bannerViewDidReceiveAd(_ bannerView: BannerView) {
      onLoadStateChanged(true)
    }

    func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
      print("[AdMob] Banner load failed: \(error.localizedDescription)")
      onLoadStateChanged(false)
    }
  }
}
