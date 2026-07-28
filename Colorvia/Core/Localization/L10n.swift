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

  static func selectedPrefectureCount(_ count: Int) -> String {
    String(format: text("format.selected_prefecture_count"), locale: .current, count)
  }

  static func visitedMapValue(_ count: Int) -> String {
    String(format: text("format.map_visited"), locale: .current, count)
  }

  static func shareMessage(_ count: Int) -> String {
    String(format: text("format.share_message"), locale: .current, count)
  }

  static func visitedCountrySummary(_ count: Int) -> String {
    String(format: text("format.visited_country_summary"), locale: .current, count)
  }

  static func visitedPrefectureSummary(_ count: Int) -> String {
    String(format: text("format.visited_prefecture_summary"), locale: .current, count)
  }

  static func japanRowStatus(isVisited: Bool, prefectureCount: Int) -> String {
    String(
      format: text(
        isVisited ? "format.japan_row_visited" : "format.japan_row_unvisited"
      ),
      locale: .current,
      prefectureCount
    )
  }

  static func removeCountryPrompt(_ countryName: String) -> String {
    String(format: text("format.remove_country_prompt"), locale: .current, countryName)
  }

  static func removeJapanMessage(_ prefectureCount: Int) -> String {
    String(format: text("format.remove_japan_message"), locale: .current, prefectureCount)
  }

  static func japanExploredPercentage(_ percentage: String) -> String {
    String(format: text("format.japan_explored"), locale: .current, percentage)
  }

  static func japanShareMessage(_ count: Int) -> String {
    String(format: text("format.japan_share_message"), locale: .current, count)
  }

  static func prefectureFraction(_ count: Int) -> String {
    String(format: text("format.prefecture_fraction"), locale: .current, count)
  }

  static func percentage(_ value: String) -> String {
    String(format: text("format.percentage"), locale: .current, value)
  }

  static func number(_ value: Int) -> String {
    String(format: text("format.number"), locale: .current, value)
  }

  static func placeMatchReason(_ placeName: String) -> String {
    String(format: text("format.place_match_reason"), locale: .current, placeName)
  }

  static func selectedDepartmentCount(_ count: Int) -> String {
    String(format: text("format.selected_department_count"), locale: .current, count)
  }

  static func visitedDepartmentSummary(_ count: Int) -> String {
    String(format: text("format.visited_department_summary"), locale: .current, count)
  }

  static func franceDepartmentFraction(_ count: Int) -> String {
    String(format: text("format.france_department_fraction"), locale: .current, count)
  }

  static func franceShareMessage(_ count: Int) -> String {
    String(format: text("format.france_share_message"), locale: .current, count)
  }

  static func removeFranceMessage(_ count: Int) -> String {
    String(format: text("format.remove_france_message"), locale: .current, count)
  }

  static func franceRowStatus(isVisited: Bool, departmentCount: Int) -> String {
    String(
      format: text(
        isVisited ? "format.france_row_visited" : "format.france_row_unvisited"
      ),
      locale: .current,
      departmentCount
    )
  }

  static func selectedSubdivisionCount(_ count: Int) -> String {
    String(format: text("format.selected_subdivision_count"), locale: .current, count)
  }

  static func subdivisionRowStatus(isVisited: Bool, count: Int, total: Int) -> String {
    String(
      format: text(
        isVisited ? "format.subdivision_row_visited" : "format.subdivision_row_unvisited"
      ),
      locale: .current,
      count,
      total
    )
  }

  static func removeSubdivisionMessage(_ count: Int) -> String {
    String(format: text("format.remove_subdivision_message"), locale: .current, count)
  }
}
