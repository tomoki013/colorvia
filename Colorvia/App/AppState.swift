import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class AppState {
  private(set) var countries: [Country] = []
  private(set) var mapCountries: [MapCountry] = []
  private(set) var prefectures: [Prefecture] = []
  private(set) var mapPrefectures: [MapPrefecture] = []
  private(set) var japanPlaceAliases: [PlaceSearchAlias] = []
  private(set) var franceDepartments: [FranceDepartment] = []
  private(set) var mapFranceDepartments: [MapPrefecture] = []
  private(set) var francePlaceAliases: [PlaceSearchAlias] = []
  private(set) var subdivisionsByCountry: [String: [AdministrativeSubdivision]] = [:]
  private(set) var subdivisionGeometryByCountry: [String: [MapPrefecture]] = [:]
  private(set) var visitedCodes: Set<String> = []
  private(set) var visitedSubdivisionCodesByCountry: [String: Set<String>] = [:]
  private(set) var isLoading = true
  var hasCompletedOnboarding: Bool
  var appearance: AppearancePreference
  var mapColor: MapColorPreference
  var lastError: String?

  private let repository: any VisitStateRepository
  private let defaults: UserDefaults
  private var countryVisitStatesByCode: [String: CountryVisitState] = [:]
  private var regionVisitStatesByCountry: [String: [String: RegionVisitState]] = [:]

  init(
    defaults: UserDefaults = .standard,
    repository: any VisitStateRepository = FileVisitStateRepository()
  ) {
    self.defaults = defaults
    self.repository = repository
    hasCompletedOnboarding = defaults.bool(forKey: PreferenceKeys.onboardingCompleted)
    appearance =
      AppearancePreference(rawValue: defaults.string(forKey: PreferenceKeys.appearance) ?? "")
      ?? .system
    mapColor =
      MapColorPreference(rawValue: defaults.string(forKey: PreferenceKeys.mapColor) ?? "")
      ?? .teal
  }

  func load() async {
    do {
      async let loadedCountries = CountryCatalog.load()
      async let loadedMap = WorldMapStore.load()
      async let loadedPrefectures = PrefectureCatalog.load()
      async let loadedJapanMap = JapanMapStore.load()
      async let loadedJapanAliases = PlaceSearchIndexStore.load(
        resourceName: "japan-place-search-index"
      )
      async let loadedFranceDepartments = FranceDepartmentStore.load()
      async let loadedFranceMap = FranceMapStore.load()
      async let loadedFranceAliases = PlaceSearchIndexStore.load(
        resourceName: "france-place-search-index"
      )
      async let visitData = repository.loadData()
      async let additionalSubdivisions = Self.loadAdditionalSubdivisionResources()
      countries = try await loadedCountries
      mapCountries = try await loadedMap
      prefectures = try await loadedPrefectures
      mapPrefectures = try await loadedJapanMap
      japanPlaceAliases = try await loadedJapanAliases
      franceDepartments = try await loadedFranceDepartments
      mapFranceDepartments = try await loadedFranceMap
      francePlaceAliases = try await loadedFranceAliases
      let additional = try await additionalSubdivisions
      subdivisionsByCountry = additional.catalogs
      subdivisionGeometryByCountry = additional.geometries
      subdivisionsByCountry["JP"] = prefectures.map { prefecture in
        AdministrativeSubdivision(
          id: prefecture.id,
          countryCode: "JP",
          code: prefecture.id.replacingOccurrences(of: "JP-", with: ""),
          nativeName: prefecture.japaneseName,
          localizedNames: [
            "en": prefecture.englishName,
            "ja": prefecture.japaneseName,
          ],
          sourceUnitIDs: [prefecture.id],
          groupCode: prefecture.region.rawValue,
          localizedGroupNames: [
            "en": prefecture.region.localizedName,
            "ja": prefecture.region.localizedName,
          ],
          displayOrder: prefectures.firstIndex(of: prefecture) ?? 0,
          semanticType: .administrative
        )
      }
      subdivisionGeometryByCountry["JP"] = mapPrefectures
      subdivisionsByCountry["FR"] = franceDepartments.map { department in
        AdministrativeSubdivision(
          id: department.id,
          countryCode: "FR",
          code: department.code,
          nativeName: department.nativeName,
          localizedNames: department.localizedNames
            ?? ["en": department.nativeName, "fr": department.nativeName],
          sourceUnitIDs: [department.id],
          groupCode: department.groupCode,
          localizedGroupNames: [
            "en": department.groupName,
            "fr": department.groupName,
          ],
          displayOrder: department.displayOrder,
          semanticType: .administrative
        )
      }
      subdivisionGeometryByCountry["FR"] = mapFranceDepartments
      let data = try await visitData
      visitedCodes = Set(data.countryStates.filter(\.isVisited).map(\.countryCode))
      countryVisitStatesByCode = Dictionary(
        uniqueKeysWithValues: data.countryStates.map { ($0.countryCode, $0) }
      )
      for country in countries where countryVisitStatesByCode[country.id] == nil {
        countryVisitStatesByCode[country.id] = CountryVisitState(
          countryCode: country.id,
          isVisited: false,
          updatedAt: .distantPast
        )
      }
      regionVisitStatesByCountry = Dictionary(
        grouping: data.regionStates,
        by: \.countryCode
      ).mapValues { Dictionary(uniqueKeysWithValues: $0.map { ($0.regionID, $0) }) }
      rebuildVisitedSubdivisionCodes()
    } catch {
      lastError = error.localizedDescription
    }
    isLoading = false
  }

  func completeOnboarding(with codes: Set<String>) async {
    visitedCodes = codes
    let now = Date()
    for country in countries {
      countryVisitStatesByCode[country.id] = CountryVisitState(
        countryCode: country.id,
        isVisited: codes.contains(country.id),
        updatedAt: now
      )
    }
    hasCompletedOnboarding = true
    defaults.set(true, forKey: PreferenceKeys.onboardingCompleted)
    await persist()
  }

  func setVisited(_ visited: Bool, countryCode: String) async {
    guard visitedCodes.contains(countryCode) != visited else { return }
    countryVisitStatesByCode[countryCode] = CountryVisitState(
      countryCode: countryCode,
      isVisited: visited,
      updatedAt: Date()
    )
    if visited {
      visitedCodes.insert(countryCode)
    } else {
      visitedCodes.remove(countryCode)
      clearVisitedRegions(countryCode: countryCode, updatedAt: Date())
    }
    await persist()
  }

  func setPrefectureVisited(_ visited: Bool, prefectureCode: String) async {
    var selection = visitedPrefectureCodes
    if visited { selection.insert(prefectureCode) } else { selection.remove(prefectureCode) }
    await replaceVisitedPrefectures(with: selection)
  }

  func replaceVisitedPrefectures(with codes: Set<String>) async {
    guard visitedCodes.contains("JP") else { return }
    updateRegionSelection(
      countryCode: "JP",
      selection: codes,
      validCodes: Set(prefectures.map(\.id))
    )
    await persist()
  }

  func replaceVisitedFranceDepartments(with codes: Set<String>) async {
    guard visitedCodes.contains("FR") else { return }
    updateRegionSelection(
      countryCode: "FR",
      selection: codes,
      validCodes: Set(franceDepartments.map(\.id))
    )
    await persist()
  }

  func replaceVisitedSubdivisions(countryCode: String, with codes: Set<String>) async {
    guard visitedCodes.contains(countryCode) else { return }
    let validCodes = Set(subdivisionsByCountry[countryCode, default: []].map(\.id))
    updateRegionSelection(countryCode: countryCode, selection: codes, validCodes: validCodes)
    await persist()
  }

  func replaceVisitedCountries(with codes: Set<String>) async {
    let now = Date()
    for countryCode in visitedCodes.symmetricDifference(codes) {
      countryVisitStatesByCode[countryCode] = CountryVisitState(
        countryCode: countryCode,
        isVisited: codes.contains(countryCode),
        updatedAt: now
      )
    }
    visitedCodes = codes
    for countryCode in Array(visitedSubdivisionCodesByCountry.keys)
    where !codes.contains(countryCode) {
      clearVisitedRegions(countryCode: countryCode, updatedAt: now)
    }
    await persist()
  }

  func resetAllData() async {
    let now = Date()
    for countryCode in visitedCodes {
      countryVisitStatesByCode[countryCode] = CountryVisitState(
        countryCode: countryCode,
        isVisited: false,
        updatedAt: now
      )
      clearVisitedRegions(countryCode: countryCode, updatedAt: now)
    }
    visitedCodes.removeAll()
    hasCompletedOnboarding = false
    defaults.set(false, forKey: PreferenceKeys.onboardingCompleted)
    await persist()
  }

  func exportedVisitData() throws -> Data {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    return try encoder.encode(currentVisitData())
  }

  func importVisitData(
    _ data: Data,
    repairUnvisitedParents: Bool? = nil
  ) async throws {
    let decoded = try FileVisitStateRepository.decode(data)
    let validCountryCodes = Set(countries.map(\.id))
    var validSubdivisionCodes: [String: Set<String>] = [
      "JP": Set(prefectures.map(\.id)),
      "FR": Set(franceDepartments.map(\.id)),
    ]
    for (countryCode, subdivisions) in subdivisionsByCountry {
      validSubdivisionCodes[countryCode] = Set(subdivisions.map(\.id))
    }

    var importedCountryCodes = Set(
      decoded.countryStates
        .filter { $0.isVisited && validCountryCodes.contains($0.countryCode) }
        .map(\.countryCode)
    )
    let validImportedRegionStates = decoded.regionStates.filter {
      validSubdivisionCodes[$0.countryCode]?.contains($0.regionID) == true
    }
    let orphanedParents = Set(
      validImportedRegionStates.lazy
        .filter(\.isVisited)
        .map(\.countryCode)
        .filter { !importedCountryCodes.contains($0) }
    )
    if !orphanedParents.isEmpty, repairUnvisitedParents == nil {
      throw VisitDataImportError.unvisitedParentCountries(orphanedParents.sorted())
    }
    if repairUnvisitedParents == true {
      importedCountryCodes.formUnion(orphanedParents)
    }

    let now = Date()
    visitedCodes = importedCountryCodes
    countryVisitStatesByCode = Dictionary(
      uniqueKeysWithValues: countries.map { country in
        let imported = decoded.countryStates.first { $0.countryCode == country.id }
        let isVisited = importedCountryCodes.contains(country.id)
        return (
          country.id,
          CountryVisitState(
            countryCode: country.id,
            isVisited: isVisited,
            updatedAt: imported?.updatedAt ?? now
          )
        )
      }
    )
    regionVisitStatesByCountry.removeAll()
    for state in validImportedRegionStates {
      guard
        importedCountryCodes.contains(state.countryCode)
      else { continue }
      regionVisitStatesByCountry[state.countryCode, default: [:]][state.regionID] = state
    }
    rebuildVisitedSubdivisionCodes()
    await persist()
  }

  func setAppearance(_ appearance: AppearancePreference) {
    self.appearance = appearance
    defaults.set(appearance.rawValue, forKey: PreferenceKeys.appearance)
  }

  func setMapColor(_ mapColor: MapColorPreference) {
    self.mapColor = mapColor
    defaults.set(mapColor.rawValue, forKey: PreferenceKeys.mapColor)
  }

  var visitedCountryCount: Int {
    countries.lazy.filter { $0.isProgressEligible && self.visitedCodes.contains($0.id) }.count
  }

  var worldPercentage: Double {
    Double(visitedCountryCount) / 195.0 * 100
  }

  var visitedPrefectureCount: Int {
    visitedPrefectureCodes.count
  }

  var visitedPrefectureCodes: Set<String> {
    visitedSubdivisionCodesByCountry["JP"] ?? []
  }

  var visitedFranceDepartmentCodes: Set<String> {
    visitedSubdivisionCodesByCountry["FR"] ?? []
  }

  func visitedSubdivisionCodes(countryCode: String) -> Set<String> {
    visitedSubdivisionCodesByCountry[countryCode] ?? []
  }

  func visitedSubdivisionCount(countryCode: String) -> Int {
    visitedSubdivisionCodes(countryCode: countryCode).count
  }

  func subdivisionPercentage(countryCode: String) -> Double {
    guard
      let total = CountrySubdivisionRegistry.definition(for: countryCode)?.totalCount,
      total > 0
    else { return 0 }
    return Double(visitedSubdivisionCount(countryCode: countryCode)) / Double(total) * 100
  }

  func visitedSubdivisionCount(countryCode: String, groupCode: String) -> Int {
    subdivisionsByCountry[countryCode, default: []].lazy.filter {
      $0.groupCode == groupCode
        && self.visitedSubdivisionCodes(countryCode: countryCode).contains($0.id)
    }.count
  }

  var visitedFranceDepartmentCount: Int {
    visitedFranceDepartmentCodes.count
  }

  var francePercentage: Double {
    Double(visitedFranceDepartmentCount) / 101.0 * 100
  }

  func visitedFranceDepartmentCount(in groupCode: String) -> Int {
    franceDepartments.lazy.filter {
      $0.groupCode == groupCode && self.visitedFranceDepartmentCodes.contains($0.id)
    }.count
  }

  var japanPercentage: Double {
    Double(visitedPrefectureCount) / 47.0 * 100
  }

  func visitedPrefectureCount(in region: JapanRegion) -> Int {
    prefectures.lazy.filter {
      $0.region == region && self.visitedPrefectureCodes.contains($0.id)
    }.count
  }

  func visitedCount(in continent: Continent) -> Int {
    countries.lazy.filter { $0.continent == continent && self.visitedCodes.contains($0.id) }.count
  }

  private func persist() async {
    do {
      try await repository.saveData(currentVisitData())
    } catch {
      lastError = error.localizedDescription
    }
  }

  private func currentVisitData() -> VisitData {
    return VisitData(
      countryStates: countryVisitStatesByCode.values.sorted { $0.countryCode < $1.countryCode },
      regionStates: regionVisitStatesByCountry.values
        .flatMap(\.values)
        .sorted {
          ($0.countryCode, $0.regionID) < ($1.countryCode, $1.regionID)
        }
    )
  }

  private func updateRegionSelection(
    countryCode: String,
    selection: Set<String>,
    validCodes: Set<String>
  ) {
    let selection = selection.intersection(validCodes)
    let current = visitedSubdivisionCodes(countryCode: countryCode)
    let now = Date()
    for regionID in current.symmetricDifference(selection) {
      regionVisitStatesByCountry[countryCode, default: [:]][regionID] = RegionVisitState(
        countryCode: countryCode,
        regionID: regionID,
        isVisited: selection.contains(regionID),
        updatedAt: now
      )
    }
    visitedSubdivisionCodesByCountry[countryCode] = selection
  }

  private func clearVisitedRegions(countryCode: String, updatedAt: Date) {
    for regionID in visitedSubdivisionCodes(countryCode: countryCode) {
      regionVisitStatesByCountry[countryCode, default: [:]][regionID] = RegionVisitState(
        countryCode: countryCode,
        regionID: regionID,
        isVisited: false,
        updatedAt: updatedAt
      )
    }
    visitedSubdivisionCodesByCountry.removeValue(forKey: countryCode)
  }

  private func rebuildVisitedSubdivisionCodes() {
    visitedSubdivisionCodesByCountry = regionVisitStatesByCountry.reduce(into: [:]) {
      result, entry in
      let visited = Set(entry.value.values.filter(\.isVisited).map(\.regionID))
      if !visited.isEmpty, visitedCodes.contains(entry.key) {
        result[entry.key] = visited
      }
    }
  }

  nonisolated private static func loadAdditionalSubdivisionResources() async throws -> (
    catalogs: [String: [AdministrativeSubdivision]],
    geometries: [String: [MapPrefecture]]
  ) {
    let definitions = CountrySubdivisionRegistry.definitions.filter {
      !["JP", "FR"].contains($0.countryCode)
    }
    return try await withThrowingTaskGroup(
      of: (String, [AdministrativeSubdivision], [MapPrefecture]).self
    ) { group in
      for definition in definitions {
        group.addTask {
          async let catalog = AdministrativeSubdivisionStore.load(
            resourceName: definition.catalogResourceName
          )
          async let geometry = AdministrativeSubdivisionStore.loadGeometry(
            resourceName: definition.geometryResourceName
          )
          return (
            definition.countryCode,
            try await catalog,
            try await geometry
          )
        }
      }
      var catalogs: [String: [AdministrativeSubdivision]] = [:]
      var geometries: [String: [MapPrefecture]] = [:]
      for try await (countryCode, catalog, geometry) in group {
        catalogs[countryCode] = catalog
        geometries[countryCode] = geometry
      }
      return (catalogs, geometries)
    }
  }
}

enum VisitDataImportError: LocalizedError, Equatable {
  case unvisitedParentCountries([String])

  var errorDescription: String? {
    switch self {
    case .unvisitedParentCountries(let codes):
      "地域データがありますが、親の国が未訪問です: \(codes.joined(separator: ", "))"
    }
  }
}

enum PreferenceKeys {
  static let onboardingCompleted = "onboarding.completed"
  static let appearance = "appearance"
  static let mapColor = "mapColor"
}

enum MapColorPreference: String, Codable, CaseIterable, Sendable {
  case teal
  case ocean
  case coral
  case amber

  var localizedName: String {
    switch self {
    case .teal: L10n.text("settings.map_color.teal")
    case .ocean: L10n.text("settings.map_color.ocean")
    case .coral: L10n.text("settings.map_color.coral")
    case .amber: L10n.text("settings.map_color.amber")
    }
  }

  var color: Color {
    switch self {
    case .teal:
      ColorviaTheme.accent
    case .ocean:
      Color(
        uiColor: UIColor { traits in
          traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.34, green: 0.65, blue: 0.91, alpha: 1)
            : UIColor(red: 0.20, green: 0.49, blue: 0.76, alpha: 1)
        })
    case .coral:
      Color(
        uiColor: UIColor { traits in
          traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.94, green: 0.48, blue: 0.43, alpha: 1)
            : UIColor(red: 0.82, green: 0.32, blue: 0.29, alpha: 1)
        })
    case .amber:
      Color(
        uiColor: UIColor { traits in
          traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.95, green: 0.68, blue: 0.24, alpha: 1)
            : UIColor(red: 0.78, green: 0.49, blue: 0.08, alpha: 1)
        })
    }
  }
}

enum AppearancePreference: String, Codable, CaseIterable, Sendable {
  case system
  case light
  case dark

  var colorScheme: ColorScheme? {
    switch self {
    case .system: nil
    case .light: .light
    case .dark: .dark
    }
  }

  var localizedName: String {
    switch self {
    case .system: L10n.text("settings.appearance.system")
    case .light: L10n.text("settings.appearance.light")
    case .dark: L10n.text("settings.appearance.dark")
    }
  }
}
