import Foundation

struct PlaceSearchAlias: Identifiable, Codable, Hashable, Sendable {
  let id: String
  let countryCode: String
  let targetRegionIDs: [String]
  let displayName: String
  let localizedDisplayNames: [String: String]
  let normalizedTerms: [String]
  let type: PlaceAliasType
  let priority: Int

  var subdivisionCode: String {
    targetRegionIDs.first ?? ""
  }

  var localizedDisplayName: String {
    let identifier = Locale.current.identifier.lowercased()
    let language =
      if identifier.contains("hant") {
        "zh-Hant"
      } else if identifier.contains("hans") {
        "zh-Hans"
      } else if identifier.hasPrefix("pt") {
        "pt-BR"
      } else {
        Locale.current.language.languageCode?.identifier ?? "en"
      }
    return localizedDisplayNames[language] ?? localizedDisplayNames["en"] ?? displayName
  }

  private enum CodingKeys: String, CodingKey {
    case id, countryCode, targetRegionIDs, subdivisionCode
    case displayName, nativeDisplayName, localizedDisplayNames, normalizedTerms, type, priority
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(String.self, forKey: .id)
    countryCode = try container.decode(String.self, forKey: .countryCode)
    if let targets = try container.decodeIfPresent([String].self, forKey: .targetRegionIDs) {
      targetRegionIDs = targets
    } else {
      targetRegionIDs = [try container.decode(String.self, forKey: .subdivisionCode)]
    }
    displayName =
      try container.decodeIfPresent(String.self, forKey: .nativeDisplayName)
      ?? container.decode(String.self, forKey: .displayName)
    localizedDisplayNames =
      try container.decodeIfPresent([String: String].self, forKey: .localizedDisplayNames) ?? [:]
    normalizedTerms = try container.decode([String].self, forKey: .normalizedTerms)
    type = try container.decode(PlaceAliasType.self, forKey: .type)
    priority = try container.decode(Int.self, forKey: .priority)
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(id, forKey: .id)
    try container.encode(countryCode, forKey: .countryCode)
    try container.encode(targetRegionIDs, forKey: .targetRegionIDs)
    try container.encode(displayName, forKey: .nativeDisplayName)
    try container.encode(localizedDisplayNames, forKey: .localizedDisplayNames)
    try container.encode(normalizedTerms, forKey: .normalizedTerms)
    try container.encode(type, forKey: .type)
    try container.encode(priority, forKey: .priority)
  }
}

enum PlaceAliasType: String, Codable, Sendable {
  case region
  case subdivision
  case municipality
  case municipalWard
  case district
  case neighborhood
  case island
  case airport
  case commonName
  case touristArea
  case landmark
}

enum PlaceSearchNormalizer {
  static func normalize(_ value: String) -> String {
    let punctuationNormalized =
      value
      .replacingOccurrences(of: "’", with: "'")
      .replacingOccurrences(of: "‐", with: "-")
      .replacingOccurrences(of: "‑", with: "-")
      .replacingOccurrences(of: "–", with: "-")
      .replacingOccurrences(of: "—", with: "-")
      .replacingOccurrences(of: "œ", with: "oe")
      .replacingOccurrences(of: "Œ", with: "OE")
    let folded = punctuationNormalized.folding(
      options: [.caseInsensitive, .widthInsensitive, .diacriticInsensitive],
      locale: Locale(identifier: "en_US_POSIX")
    )
    let katakana =
      folded.applyingTransform(.hiraganaToKatakana, reverse: false) ?? folded
    return
      katakana
      .replacingOccurrences(of: "[-'・]", with: " ", options: .regularExpression)
      .replacingOccurrences(of: "[市区町村]$", with: "", options: .regularExpression)
      .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .lowercased()
      .replacingOccurrences(of: "ı", with: "i")
  }
}

enum PlaceSearchService {
  static func bestMatches(
    query: String,
    aliases: [PlaceSearchAlias]
  ) -> [String: PlaceSearchAlias] {
    let normalizedQuery = PlaceSearchNormalizer.normalize(query)
    guard !normalizedQuery.isEmpty else { return [:] }

    var bestBySubdivision: [String: (alias: PlaceSearchAlias, score: Int)] = [:]
    for alias in aliases {
      guard
        let matchScore = alias.normalizedTerms.compactMap({
          Self.scoreWithVariants(query: normalizedQuery, term: $0)
        }).max()
      else { continue }
      let totalScore = matchScore + alias.priority
      for regionID in alias.targetRegionIDs {
        if totalScore > bestBySubdivision[regionID]?.score ?? .min {
          bestBySubdivision[regionID] = (alias, totalScore)
        }
      }
    }
    return bestBySubdivision.mapValues(\.alias)
  }

  private static func scoreWithVariants(query: String, term: String) -> Int? {
    let queryVariants = [
      query,
      query.replacingOccurrences(of: " ", with: ""),
      query.replacingOccurrences(of: "ー", with: ""),
    ]
    let termVariants = [
      term,
      term.replacingOccurrences(of: " ", with: ""),
      term.replacingOccurrences(of: "ー", with: ""),
    ]
    return zip(queryVariants, termVariants).compactMap { score(query: $0, term: $1) }.max()
  }

  private static func score(query: String, term: String) -> Int? {
    if term == query { return 1_000 }
    if term.hasPrefix(query) { return 700 }
    if term.contains(query) { return 400 }
    return nil
  }
}

enum PlaceSearchIndexStore {
  static func load(resourceName: String) async throws -> [PlaceSearchAlias] {
    guard let url = Bundle.main.url(forResource: resourceName, withExtension: "json") else {
      throw CocoaError(.fileNoSuchFile)
    }
    let data = try Data(contentsOf: url)
    return try JSONDecoder().decode([PlaceSearchAlias].self, from: data)
  }
}
