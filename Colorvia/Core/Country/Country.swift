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
    [localizedName, japaneseName, englishName, alpha2Code, alpha3Code]
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

struct RegionVisitState: Codable, Hashable, Sendable {
  let countryCode: String
  let regionID: String
  var isVisited: Bool
  var updatedAt: Date
}

struct VisitData: Codable, Hashable, Sendable {
  var version = 5
  var countryStates: [CountryVisitState] = []
  var regionStates: [RegionVisitState] = []

  var subdivisionCodesByCountry: [String: Set<String>] {
    get {
      Dictionary(grouping: regionStates.filter(\.isVisited), by: \.countryCode)
        .mapValues { Set($0.map(\.regionID)) }
    }
    set {
      let now = Date()
      regionStates = newValue.flatMap { countryCode, regionIDs in
        regionIDs.map {
          RegionVisitState(
            countryCode: countryCode,
            regionID: $0,
            isVisited: true,
            updatedAt: now
          )
        }
      }
    }
  }

  var visitedPrefectureCodes: Set<String> {
    get { subdivisionCodesByCountry["JP"] ?? [] }
    set { subdivisionCodesByCountry["JP"] = newValue }
  }

  init(
    version: Int = 5,
    countryStates: [CountryVisitState] = [],
    subdivisionCodesByCountry: [String: Set<String>] = [:],
    regionStates: [RegionVisitState]? = nil
  ) {
    self.version = version
    self.countryStates = countryStates
    if let regionStates {
      self.regionStates = regionStates
    } else {
      self.subdivisionCodesByCountry = subdivisionCodesByCountry
    }
  }

  init(
    countryStates: [CountryVisitState],
    visitedPrefectureCodes: Set<String> = []
  ) {
    self.countryStates = countryStates
    self.subdivisionCodesByCountry = ["JP": visitedPrefectureCodes]
  }

  private enum CodingKeys: String, CodingKey {
    case version
    case formatVersion
    case countryStates
    case countries
    case regions
    case subdivisionCodesByCountry
    case visitedPrefectureCodes
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    version =
      try container.decodeIfPresent(Int.self, forKey: .formatVersion)
      ?? container.decodeIfPresent(Int.self, forKey: .version)
      ?? 2
    countryStates =
      try container.decodeIfPresent([CountryVisitState].self, forKey: .countries)
      ?? container.decodeIfPresent([CountryVisitState].self, forKey: .countryStates)
      ?? []
    if let currentRegions = try container.decodeIfPresent(
      [RegionVisitState].self,
      forKey: .regions
    ) {
      regionStates = currentRegions
    } else {
      let legacySubdivisions =
        try container.decodeIfPresent(
          [String: Set<String>].self,
          forKey: .subdivisionCodesByCountry
        ) ?? [:]
      var migrated = legacySubdivisions
      if migrated["JP"] == nil,
        let legacy = try container.decodeIfPresent(
          Set<String>.self,
          forKey: .visitedPrefectureCodes
        )
      {
        migrated["JP"] = legacy
      }
      regionStates = migrated.flatMap { countryCode, regionIDs in
        regionIDs.map {
          RegionVisitState(
            countryCode: countryCode,
            regionID: $0,
            isVisited: true,
            updatedAt: .distantPast
          )
        }
      }
    }
    version = 5
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(5, forKey: .formatVersion)
    try container.encode(countryStates, forKey: .countries)
    try container.encode(regionStates, forKey: .regions)
  }
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
