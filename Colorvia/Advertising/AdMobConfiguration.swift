import Foundation

enum AdMobConfiguration {
  /// Google official test banner unit ID (Debug only).
  private static let testBannerAdUnitID = "ca-app-pub-3940256099942544/2435281174"

  static var bannerAdUnitID: String {
    #if DEBUG
      return testBannerAdUnitID
    #else
      guard
        let value = Bundle.main.object(
          forInfoDictionaryKey: "ADMOB_BANNER_AD_UNIT_ID"
        ) as? String,
        !value.isEmpty,
        value != testBannerAdUnitID
      else {
        assertionFailure("ADMOB_BANNER_AD_UNIT_ID is missing or still a test ID")
        return ""
      }

      return value
    #endif
  }
}
