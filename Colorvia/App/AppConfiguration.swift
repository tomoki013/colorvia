import Foundation

struct AppConfiguration: Sendable, Equatable {
  let adsEnabled: Bool
  let cloudSyncEnabled: Bool
  let admobAppID: String?
  let bannerAdUnitID: String?
  let privacyPolicyURL: URL
  let termsURL: URL
  let supportURL: URL
  let marketingURL: URL
  /// What the app sends so the support API can ignore everything that is not
  /// one of our apps. Not a credential — it ships inside the binary — and the
  /// API treats it as a filter rather than as authentication: it stops a bare
  /// `curl` claiming `source: "colorvia-ios"`, not somebody who has opened the
  /// binary. Injected from the build setting of the same name; `nil` in a build
  /// that has not set one, in which case the header is simply not sent.
  let supportClientKey: String?

  static let current = AppConfiguration(bundle: .main)

  init(
    adsEnabled: Bool,
    cloudSyncEnabled: Bool,
    admobAppID: String?,
    bannerAdUnitID: String?,
    privacyPolicyURL: URL,
    termsURL: URL,
    supportURL: URL,
    marketingURL: URL,
    supportClientKey: String? = nil
  ) {
    self.adsEnabled = adsEnabled
    self.cloudSyncEnabled = cloudSyncEnabled
    self.admobAppID = Self.nonEmpty(admobAppID)
    self.bannerAdUnitID = Self.nonEmpty(bannerAdUnitID)
    self.privacyPolicyURL = privacyPolicyURL
    self.termsURL = termsURL
    self.supportURL = supportURL
    self.marketingURL = marketingURL
    self.supportClientKey = Self.nonEmpty(supportClientKey)
  }

  init(bundle: Bundle) {
    adsEnabled = Self.boolValue(bundle.object(forInfoDictionaryKey: "ADS_ENABLED"))
    cloudSyncEnabled = Self.boolValue(
      bundle.object(forInfoDictionaryKey: "CLOUD_SYNC_ENABLED")
    )
    admobAppID = Self.nonEmpty(
      bundle.object(forInfoDictionaryKey: "ADMOB_APP_ID") as? String
    )
    bannerAdUnitID = Self.nonEmpty(
      bundle.object(forInfoDictionaryKey: "ADMOB_BANNER_AD_UNIT_ID") as? String
    )
    privacyPolicyURL = Self.url(
      bundle.object(forInfoDictionaryKey: "PRIVACY_POLICY_URL") as? String,
      fallback: "https://colorvia.tmkch.io/privacy"
    )
    termsURL = Self.url(
      bundle.object(forInfoDictionaryKey: "TERMS_URL") as? String,
      fallback: "https://colorvia.tmkch.io/terms"
    )
    supportURL = Self.url(
      bundle.object(forInfoDictionaryKey: "SUPPORT_URL") as? String,
      fallback: "https://tmkch.io/support?app=colorvia"
    )
    marketingURL = Self.url(
      bundle.object(forInfoDictionaryKey: "MARKETING_URL") as? String,
      fallback: "https://colorvia.tmkch.io"
    )
    supportClientKey = Self.nonEmpty(
      bundle.object(forInfoDictionaryKey: "SUPPORT_CLIENT_KEY") as? String
    )
  }

  var hasCompleteAdMobConfiguration: Bool {
    admobAppID != nil && bannerAdUnitID != nil
  }

  private static func boolValue(_ value: Any?) -> Bool {
    if let value = value as? Bool { return value }
    guard let value = (value as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
      .lowercased()
    else { return false }
    return ["1", "true", "yes"].contains(value)
  }

  private static func nonEmpty(_ value: String?) -> String? {
    guard let value else { return nil }
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, !trimmed.contains("$(") else { return nil }
    return trimmed
  }

  private static func url(_ value: String?, fallback: String) -> URL {
    URL(string: nonEmpty(value) ?? fallback) ?? URL(fileURLWithPath: "/")
  }
}
