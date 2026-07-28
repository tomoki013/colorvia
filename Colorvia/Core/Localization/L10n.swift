import Foundation

enum L10n {
  static func text(_ key: String.LocalizationValue) -> String {
    String(localized: key)
  }

  static func countryCount(_ count: Int) -> String {
    if count == 1 {
      return text("format.country_count_one")
    }
    return String(format: text("format.country_count"), locale: .current, count)
  }

  static func countryUnit(_ count: Int) -> String {
    count == 1 ? text("unit.country_one") : text("unit.countries")
  }

  static func selectedCount(_ count: Int) -> String {
    String(format: text("format.selected_count"), locale: .current, count)
  }

  static func visitedMapValue(_ count: Int) -> String {
    String(format: text("format.map_visited"), locale: .current, count)
  }

  static func shareMessage(_ count: Int) -> String {
    String(format: text("format.share_message"), locale: .current, count)
  }
}
