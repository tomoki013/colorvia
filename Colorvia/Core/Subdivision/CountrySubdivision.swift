import Foundation

enum RegionSchemeKind: String, Codable, CaseIterable, Sendable {
  case administrative
  case administrativeComposite
  case hybrid
  case travelArea
}

enum RegionSemanticType: String, Codable, Sendable {
  case administrative
  case territory
  case travelArea
}

struct RegionSourceUnit: Identifiable, Codable, Hashable, Sendable {
  let id: String
  let countryCode: String
  let sourceCode: String
  let sourceLevel: String
  let geometryResourceID: String
}

struct RecordableRegion: Identifiable, Hashable, Sendable {
  let id: String
  let countryCode: String
  let code: String
  let nativeName: String
  let localizedNames: [String: String]
  let sourceUnitIDs: [String]
  let groupCode: String
  let localizedGroupNames: [String: String]
  let displayOrder: Int
  let semanticType: RegionSemanticType

  var localizedName: String {
    localizedNames[Self.languageKey]
      ?? localizedNames[Locale.current.language.languageCode?.identifier ?? "en"]
      ?? localizedNames["en"]
      ?? nativeName
  }

  var localizedGroupName: String {
    localizedGroupNames[Self.languageKey]
      ?? localizedGroupNames[Locale.current.language.languageCode?.identifier ?? "en"]
      ?? localizedGroupNames["en"]
      ?? groupCode
  }

  private static var languageKey: String {
    let identifier = Locale.current.identifier.lowercased()
    if identifier.contains("hant") { return "zh-Hant" }
    if identifier.contains("hans") { return "zh-Hans" }
    if identifier.hasPrefix("pt") { return "pt-BR" }
    return Locale.current.language.languageCode?.identifier ?? "en"
  }
}

extension RecordableRegion: Codable {
  private enum CodingKeys: String, CodingKey {
    case id, countryCode, code, nativeName, localizedNames, sourceUnitIDs
    case groupCode, localizedGroupNames, displayOrder, semanticType
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(String.self, forKey: .id)
    countryCode = try container.decode(String.self, forKey: .countryCode)
    code = try container.decodeIfPresent(String.self, forKey: .code) ?? id
    nativeName = try container.decode(String.self, forKey: .nativeName)
    localizedNames =
      try container.decodeIfPresent(
        [String: String].self,
        forKey: .localizedNames
      ) ?? [:]
    sourceUnitIDs =
      try container.decodeIfPresent([String].self, forKey: .sourceUnitIDs) ?? [id]
    groupCode = try container.decodeIfPresent(String.self, forKey: .groupCode) ?? ""
    localizedGroupNames =
      try container.decodeIfPresent(
        [String: String].self,
        forKey: .localizedGroupNames
      ) ?? [:]
    displayOrder = try container.decodeIfPresent(Int.self, forKey: .displayOrder) ?? 0
    semanticType =
      try container.decodeIfPresent(RegionSemanticType.self, forKey: .semanticType)
      ?? .administrative
  }
}

typealias AdministrativeSubdivision = RecordableRegion

struct RegionReplacementDefinition: Codable, Hashable, Sendable {
  let replacedRecordableRegionIDs: [String]
  let replacementRegionIDs: [String]
}

struct RegionMapInset: Codable, Hashable, Sendable {
  let id: String
  let regionIDs: [String]
}

struct RegionListGroup: Codable, Hashable, Sendable {
  let code: String
  let localizedNames: [String: String]
}

struct CountryRegionScheme: Identifiable, Hashable, Sendable {
  var id: String { countryCode }
  let countryCode: String
  let kind: RegionSchemeKind
  let unitLabelKey: String
  let sourceCatalogResourceName: String
  let recordableCatalogResourceName: String
  let geometryResourceName: String
  let searchIndexResourceName: String
  let mapInsets: [RegionMapInset]
  let listGroups: [RegionListGroup]
  let expectedRegionCount: Int

  // Compatibility names used by the existing generic views.
  var totalCount: Int { expectedRegionCount }
  var catalogResourceName: String { recordableCatalogResourceName }
  var nativeUnitName: String { unitLabelKey }

  var localizedCountryName: String {
    Locale.current.localizedString(forRegionCode: countryCode) ?? countryCode
  }
}

typealias CountrySubdivisionDefinition = CountryRegionScheme

enum CountryRegionSchemeRegistry {
  static let definitions: [CountryRegionScheme] = [
    definition(
      "JP",
      47,
      "Prefectures",
      .administrative,
      source: "prefectures",
      catalog: "prefectures",
      map: "japan-map",
      search: "japan-place-search-index"
    ),
    definition(
      "FR",
      101,
      "Departments",
      .administrative,
      source: "france-departments",
      catalog: "france-departments",
      map: "france-map",
      search: "france-place-search-index"
    ),
    definition("ES", 52, "Provinces & Autonomous Cities", .administrativeComposite),
    definition("KR", 17, "Regions", .administrative),
    definition("EG", 27, "Governorates", .administrative),
    definition("TH", 77, "Provinces & Bangkok", .administrativeComposite),
    definition("TR", 81, "Provinces", .administrative),
    definition(
      "US",
      56,
      "States, D.C. & Territories",
      .administrativeComposite,
      source: "us-source-regions",
      insets: ["US-AK", "US-HI", "US-GU", "US-PR", "US-VI", "US-AS", "US-MP"]
    ),
    definition(
      "MY",
      16,
      "States & Federal Territories",
      .administrativeComposite,
      source: "my-source-regions",
      insets: ["MY-15"]
    ),
    definition(
      "BE",
      11,
      "Provinces & Brussels",
      .administrativeComposite,
      source: "be-source-regions"
    ),
    definition(
      "SG",
      8,
      "Areas",
      .travelArea,
      source: "sg-planning-areas",
      catalog: "sg-subdivisions",
      map: "sg-map",
      search: "sg-place-search-index"
    ),
  ]

  static func definition(for countryCode: String) -> CountryRegionScheme? {
    definitions.first { $0.countryCode == countryCode }
  }

  private static func definition(
    _ countryCode: String,
    _ totalCount: Int,
    _ unitLabelKey: String,
    _ kind: RegionSchemeKind,
    source: String? = nil,
    catalog: String? = nil,
    map: String? = nil,
    search: String? = nil,
    insets: [String] = []
  ) -> CountryRegionScheme {
    let prefix = countryCode.lowercased()
    return .init(
      countryCode: countryCode,
      kind: kind,
      unitLabelKey: unitLabelKey,
      sourceCatalogResourceName: source ?? "\(prefix)-subdivisions",
      recordableCatalogResourceName: catalog ?? "\(prefix)-subdivisions",
      geometryResourceName: map ?? "\(prefix)-map",
      searchIndexResourceName: search ?? "\(prefix)-place-search-index",
      mapInsets: insets.map { .init(id: $0, regionIDs: [$0]) },
      listGroups: [],
      expectedRegionCount: totalCount
    )
  }
}

typealias CountrySubdivisionRegistry = CountryRegionSchemeRegistry

enum RegionSchemeValidationError: Error, Equatable {
  case wrongRegionCount(expected: Int, actual: Int)
  case duplicateSourceUnits([String])
  case unassignedSourceUnits([String])
  case unknownSourceUnits([String])
  case emptyRegion(String)
}

enum RegionSchemeValidator {
  static func validate(
    scheme: CountryRegionScheme,
    sourceUnits: [RegionSourceUnit],
    regions: [RecordableRegion]
  ) throws {
    guard regions.count == scheme.expectedRegionCount else {
      throw RegionSchemeValidationError.wrongRegionCount(
        expected: scheme.expectedRegionCount,
        actual: regions.count
      )
    }
    if let empty = regions.first(where: \.sourceUnitIDs.isEmpty) {
      throw RegionSchemeValidationError.emptyRegion(empty.id)
    }
    let expected = Set(sourceUnits.map(\.id))
    let assigned = regions.flatMap(\.sourceUnitIDs)
    let assignedSet = Set(assigned)
    let duplicates = Dictionary(grouping: assigned, by: { $0 })
      .filter { $0.value.count > 1 }.map(\.key).sorted()
    if !duplicates.isEmpty {
      throw RegionSchemeValidationError.duplicateSourceUnits(duplicates)
    }
    let unknown = assignedSet.subtracting(expected).sorted()
    if !unknown.isEmpty {
      throw RegionSchemeValidationError.unknownSourceUnits(unknown)
    }
    let missing = expected.subtracting(assignedSet).sorted()
    if !missing.isEmpty {
      throw RegionSchemeValidationError.unassignedSourceUnits(missing)
    }
  }
}

enum AdministrativeSubdivisionStore {
  static func load(resourceName: String) async throws -> [AdministrativeSubdivision] {
    guard let url = Bundle.main.url(forResource: resourceName, withExtension: "json") else {
      throw CocoaError(.fileNoSuchFile)
    }
    return try JSONDecoder().decode(
      [AdministrativeSubdivision].self,
      from: Data(contentsOf: url)
    )
  }

  static func loadSourceUnits(resourceName: String) async throws -> [RegionSourceUnit] {
    guard let url = Bundle.main.url(forResource: resourceName, withExtension: "json") else {
      throw CocoaError(.fileNoSuchFile)
    }
    return try JSONDecoder().decode([RegionSourceUnit].self, from: Data(contentsOf: url))
  }

  static func loadGeometry(resourceName: String) async throws -> [MapPrefecture] {
    guard let url = Bundle.main.url(forResource: resourceName, withExtension: "json") else {
      throw CocoaError(.fileNoSuchFile)
    }
    return try JSONDecoder().decode([MapPrefecture].self, from: Data(contentsOf: url))
  }
}
