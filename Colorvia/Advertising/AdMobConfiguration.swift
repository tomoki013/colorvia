import Foundation

enum AdMobConfiguration {
  static var appID: String? { AppConfiguration.current.admobAppID }
  static var bannerAdUnitID: String? { AppConfiguration.current.bannerAdUnitID }
}
