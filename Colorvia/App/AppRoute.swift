import Foundation

enum AppRoute: Hashable {
  case countryDetail(countryCode: String)
  case japanMap
  case franceMap
  case subdivisionMap(countryCode: String)
}
