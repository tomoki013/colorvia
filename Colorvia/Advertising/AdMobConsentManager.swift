import AppTrackingTransparency
import Foundation
@preconcurrency import GoogleMobileAds
import Observation
import UIKit
import UserMessagingPlatform

@MainActor
protocol TrackingAuthorizationProviding: AnyObject {
  func requestIfNeeded() async
}

@MainActor
final class SystemTrackingAuthorizationProvider: TrackingAuthorizationProviding {
  static let shared = SystemTrackingAuthorizationProvider()

  func requestIfNeeded() async {
    guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined else { return }
    _ = await ATTrackingManager.requestTrackingAuthorization()
  }
}

/// Google User Messaging Platform consent, isolated behind a protocol so tests
/// never reach the network.
@MainActor
protocol ConsentGathering: AnyObject {
  /// True once UMP reports that ad requests are permitted for this user.
  var canRequestAds: Bool { get }
  /// True in regions where the user must be able to reopen the consent form.
  var isPrivacyOptionsRequired: Bool { get }
  func gatherIfNeeded() async
  func presentPrivacyOptions() async
}

@MainActor
final class UMPConsentGatherer: ConsentGathering {
  static let shared = UMPConsentGatherer()

  var canRequestAds: Bool { ConsentInformation.shared.canRequestAds }

  var isPrivacyOptionsRequired: Bool {
    ConsentInformation.shared.privacyOptionsRequirementStatus == .required
  }

  func gatherIfNeeded() async {
    let parameters = UserMessagingPlatform.RequestParameters()
    parameters.isTaggedForUnderAgeOfConsent = false

    await withCheckedContinuation { continuation in
      ConsentInformation.shared.requestConsentInfoUpdate(with: parameters) { _ in
        // A failed update leaves `canRequestAds` false, which keeps ads off.
        continuation.resume()
      }
    }

    guard let controller = PresentingViewController.current() else { return }
    await withCheckedContinuation { continuation in
      ConsentForm.loadAndPresentIfRequired(from: controller) { _ in
        continuation.resume()
      }
    }
  }

  func presentPrivacyOptions() async {
    guard let controller = PresentingViewController.current() else { return }
    await withCheckedContinuation { continuation in
      ConsentForm.presentPrivacyOptionsForm(from: controller) { _ in
        continuation.resume()
      }
    }
  }
}

enum PresentingViewController {
  @MainActor
  static func current() -> UIViewController? {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    let root =
      scenes.flatMap(\.windows).first(where: \.isKeyWindow)?.rootViewController
      ?? scenes.first?.windows.first?.rootViewController
    var presented = root
    while let next = presented?.presentedViewController {
      presented = next
    }
    return presented
  }
}

@MainActor
protocol AdService: AnyObject {
  var canShowAds: Bool { get }
  var isPrivacyOptionsRequired: Bool { get }
  func initialize() async
  func presentPrivacyOptions() async
}

extension AdService {
  var isPrivacyOptionsRequired: Bool { false }
  func presentPrivacyOptions() async {}
}

@MainActor
final class DisabledAdService: AdService {
  var canShowAds: Bool { false }
  func initialize() async {}
}

/// Release advertising. Consent is gathered before the SDK starts, and any
/// failure along the way simply leaves the app ad-free.
@MainActor
final class ProductionAdMobService: AdService {
  private let configuration: AppConfiguration
  private let trackingAuthorization: any TrackingAuthorizationProviding
  private let consent: any ConsentGathering

  private(set) var canShowAds = false

  init(
    configuration: AppConfiguration,
    trackingAuthorization: any TrackingAuthorizationProviding =
      SystemTrackingAuthorizationProvider.shared,
    consent: any ConsentGathering = UMPConsentGatherer.shared
  ) {
    self.configuration = configuration
    self.trackingAuthorization = trackingAuthorization
    self.consent = consent
  }

  var isPrivacyOptionsRequired: Bool {
    configuration.adsEnabled && consent.isPrivacyOptionsRequired
  }

  func initialize() async {
    guard configuration.adsEnabled, configuration.hasCompleteAdMobConfiguration else { return }

    // UMP first: its message can explain tracking before the system ATT alert.
    await consent.gatherIfNeeded()
    await trackingAuthorization.requestIfNeeded()

    guard consent.canRequestAds else { return }

    MobileAds.shared.requestConfiguration.setPublisherFirstPartyIDEnabled(false)
    _ = await MobileAds.shared.start()
    canShowAds = true
  }

  func presentPrivacyOptions() async {
    await consent.presentPrivacyOptions()
  }
}

/// Debug-only service backed by Google's demo app and banner unit IDs.
@MainActor
final class TestAdMobService: AdService {
  private(set) var canShowAds = false
  private let trackingAuthorization: any TrackingAuthorizationProviding

  init(
    trackingAuthorization: any TrackingAuthorizationProviding =
      SystemTrackingAuthorizationProvider.shared
  ) {
    self.trackingAuthorization = trackingAuthorization
  }

  func initialize() async {
    await trackingAuthorization.requestIfNeeded()
    MobileAds.shared.requestConfiguration.setPublisherFirstPartyIDEnabled(false)
    Task { @MainActor in
      let _ = await MobileAds.shared.start()
    }
    canShowAds = true
  }
}

/// UI-facing state. App startup and local data loading never wait for ads.
@MainActor
@Observable
final class AdServiceController {
  static let shared = AdServiceController(configuration: .current)

  private(set) var canShowAds = false
  private(set) var isPrepared = false
  private(set) var isPrivacyOptionsRequired = false
  private let service: any AdService

  init(configuration: AppConfiguration, service: (any AdService)? = nil) {
    if let service {
      self.service = service
    } else if configuration.adsEnabled {
      #if DEBUG
        self.service = TestAdMobService()
      #else
        self.service = ProductionAdMobService(configuration: configuration)
      #endif
    } else {
      self.service = DisabledAdService()
    }
  }

  func prepare() async {
    guard !isPrepared else { return }
    await service.initialize()
    canShowAds = service.canShowAds
    isPrivacyOptionsRequired = service.isPrivacyOptionsRequired
    isPrepared = true
  }

  func presentPrivacyOptions() async {
    await service.presentPrivacyOptions()
    isPrivacyOptionsRequired = service.isPrivacyOptionsRequired
  }
}
