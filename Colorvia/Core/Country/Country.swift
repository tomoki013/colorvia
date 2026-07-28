import Foundation

struct Country: Identifiable, Codable, Hashable, Sendable {
  let id: String
  let alpha2Code: String
  let alpha3Code: String
  let englishName: String
  let continent: Continent
  let isProgressEligible: Bool
  let isTerritory: Bool

  var japaneseName: String {
    Locale(identifier: "ja_JP").localizedString(forRegionCode: alpha2Code) ?? englishName
  }

  var localizedName: String {
    Locale.current.localizedString(forRegionCode: alpha2Code) ?? englishName
  }

  var flag: String {
    alpha2Code.unicodeScalars.compactMap { UnicodeScalar(127397 + $0.value) }.map(String.init)
      .joined()
  }

  var searchableText: String {
    [japaneseName, englishName, alpha2Code, alpha3Code]
      .joined(separator: " ")
      .folding(
        options: [.caseInsensitive, .widthInsensitive, .diacriticInsensitive], locale: .current
      )
      .lowercased()
  }
}

enum Continent: String, Codable, CaseIterable, Sendable {
  case asia
  case europe
  case africa
  case northAmerica
  case southAmerica
  case oceania

  var localizedName: String {
    switch self {
    case .asia: L10n.text("continent.asia")
    case .europe: L10n.text("continent.europe")
    case .africa: L10n.text("continent.africa")
    case .northAmerica: L10n.text("continent.north_america")
    case .southAmerica: L10n.text("continent.south_america")
    case .oceania: L10n.text("continent.oceania")
    }
  }
}

struct CountryVisitState: Codable, Hashable, Sendable {
  let countryCode: String
  var isVisited: Bool
  var updatedAt: Date
}

enum CountryCatalog {
  static func load() async throws -> [Country] {
    guard let url = Bundle.main.url(forResource: "countries", withExtension: "json") else {
      throw CocoaError(.fileNoSuchFile)
    }
    let data = try Data(contentsOf: url)
    return try JSONDecoder().decode([Country].self, from: data)
  }
}
