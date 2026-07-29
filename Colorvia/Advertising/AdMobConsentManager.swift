import Foundation
import GoogleMobileAds
import UserMessagingPlatform

/// Gathers UMP consent, starts Mobile Ads once, and exposes privacy-options state.
@MainActor
@Observable
final class AdMobConsentManager {
  static let shared = AdMobConsentManager()

  private(set) var canRequestAds = false
  private(set) var isPrivacyOptionsRequired = false
  private(set) var isPrepared = false

  private var didStartMobileAds = false
  private var prepareTask: Task<Void, Never>?

  private init() {}

  /// Call once from the app entry point. Safe to call again; concurrent calls share work.
  func prepare() async {
    if let prepareTask {
      await prepareTask.value
      return
    }

    let task = Task { @MainActor in
      await self.performPrepare()
    }
    prepareTask = task
    await task.value
  }

  private func performPrepare() async {
    let parameters = RequestParameters()

    do {
      try await ConsentInformation.shared.requestConsentInfoUpdate(with: parameters)
      try await ConsentForm.loadAndPresentIfRequired(from: nil)
    } catch {
      print("[AdMob] Consent error: \(error.localizedDescription)")
    }

    refreshConsentFlags()
    startMobileAdsIfNeeded()
    isPrepared = true
  }

  func presentPrivacyOptions() async {
    do {
      try await ConsentForm.presentPrivacyOptionsForm(from: nil)
      refreshConsentFlags()
    } catch {
      print("[AdMob] Privacy options error: \(error.localizedDescription)")
    }
  }

  private func refreshConsentFlags() {
    canRequestAds = ConsentInformation.shared.canRequestAds
    isPrivacyOptionsRequired =
      ConsentInformation.shared.privacyOptionsRequirementStatus == .required
  }

  private func startMobileAdsIfNeeded() {
    guard canRequestAds, !didStartMobileAds else { return }

    didStartMobileAds = true

    // Prefer map experience privacy: do not use publisher first-party IDs for ads.
    MobileAds.shared.requestConfiguration.setPublisherFirstPartyIDEnabled(false)
    MobileAds.shared.start()
  }
}
