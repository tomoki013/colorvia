import Foundation
import Testing

@testable import Colorvia

struct AppStateTests {
  @Test func continentNamesExist() {
    for continent in Continent.allCases {
      #expect(!continent.localizedName.isEmpty)
    }
  }

  @Test func mapPointDecodes() throws {
    let data = Data(#"{"x":0.5,"y":0.25}"#.utf8)
    let point = try JSONDecoder().decode(MapPoint.self, from: data)
    #expect(point.x == 0.5)
    #expect(point.y == 0.25)
  }

  @Test func appearancePreferencesProvideExpectedSchemes() {
    #expect(AppearancePreference.system.colorScheme == nil)
    #expect(AppearancePreference.light.colorScheme == .light)
    #expect(AppearancePreference.dark.colorScheme == .dark)
  }

  @Test func mapColorPreferencesAreAvailable() {
    #expect(MapColorPreference.allCases.count == 4)
    for mapColor in MapColorPreference.allCases {
      #expect(!mapColor.localizedName.isEmpty)
    }
  }

  @Test func prefectureCatalogAndMapContainMatching47Codes() async throws {
    let prefectures = try await PrefectureCatalog.load()
    let mapPrefectures = try await JapanMapStore.load()
    #expect(prefectures.count == 47)
    #expect(mapPrefectures.count == 47)
    #expect(Set(prefectures.map(\.id)) == Set(mapPrefectures.map(\.code)))
  }

  @Test func japanPlaceSearchFindsMunicipalitiesAndAliases() async throws {
    let aliases = try await PlaceSearchIndexStore.load(
      resourceName: "japan-place-search-index"
    )
    #expect(PlaceSearchService.bestMatches(query: "神戸", aliases: aliases)["JP-28"] != nil)
    #expect(PlaceSearchService.bestMatches(query: "こうべ", aliases: aliases)["JP-28"] != nil)
    #expect(PlaceSearchService.bestMatches(query: "Kobe", aliases: aliases)["JP-28"] != nil)
    #expect(PlaceSearchService.bestMatches(query: "横浜", aliases: aliases)["JP-14"] != nil)
    #expect(PlaceSearchService.bestMatches(query: "渋谷", aliases: aliases)["JP-13"] != nil)
    #expect(PlaceSearchService.bestMatches(query: "博多", aliases: aliases)["JP-40"] != nil)
    let tokyoAlias = try #require(aliases.first { $0.id == "jp-pref-JP-13" })
    for localizedName in tokyoAlias.localizedDisplayNames.values {
      #expect(
        PlaceSearchService.bestMatches(query: localizedName, aliases: aliases)["JP-13"]
          != nil
      )
    }
  }

  @Test func franceCatalogGeometryAndSearchAreComplete() async throws {
    let departments = try await FranceDepartmentStore.load()
    let geometry = try await FranceMapStore.load()
    let aliases = try await PlaceSearchIndexStore.load(
      resourceName: "france-place-search-index"
    )

    #expect(departments.count == 101)
    #expect(Set(departments.map(\.id)).count == 101)
    #expect(Set(departments.map(\.id)) == Set(geometry.map(\.code)))
    #expect(departments.contains { $0.code == "2A" })
    #expect(departments.contains { $0.code == "2B" })
    for code in ["971", "972", "973", "974", "976"] {
      #expect(departments.contains { $0.code == code })
    }
    #expect(PlaceSearchService.bestMatches(query: "Paris", aliases: aliases)["FR-75"] != nil)
    #expect(PlaceSearchService.bestMatches(query: "パリ", aliases: aliases)["FR-75"] != nil)
    #expect(PlaceSearchService.bestMatches(query: "Nice", aliases: aliases)["FR-06"] != nil)
    #expect(PlaceSearchService.bestMatches(query: "ニース", aliases: aliases)["FR-06"] != nil)
    #expect(PlaceSearchService.bestMatches(query: "Nimes", aliases: aliases)["FR-30"] != nil)
    #expect(
      PlaceSearchService.bestMatches(query: "Saint-Denis", aliases: aliases).keys.count >= 2
    )
    let parisAlias = try #require(aliases.first { $0.id == "fr-dep-75" })
    for localizedName in parisAlias.localizedDisplayNames.values {
      #expect(
        PlaceSearchService.bestMatches(query: localizedName, aliases: aliases)["FR-75"]
          != nil
      )
    }
  }

  @Test func fiveAdditionalCountryCatalogsAndGeometryHaveExpectedCounts() async throws {
    let expected = ["ES": 52, "KR": 17, "EG": 27, "TH": 77, "TR": 81]
    let requiredLanguages = Set([
      "en", "ja", "es", "fr", "de", "it", "pt-BR", "ko", "zh-Hans", "zh-Hant", "ru",
    ])
    for (countryCode, count) in expected {
      let definition = try #require(
        CountrySubdivisionRegistry.definition(for: countryCode)
      )
      let catalog = try await AdministrativeSubdivisionStore.load(
        resourceName: definition.catalogResourceName
      )
      let geometry = try await AdministrativeSubdivisionStore.loadGeometry(
        resourceName: definition.geometryResourceName
      )
      #expect(catalog.count == count)
      #expect(geometry.count == count)
      #expect(Set(catalog.map(\.id)) == Set(geometry.map(\.code)))
      #expect(catalog.allSatisfy { requiredLanguages.isSubset(of: $0.localizedNames.keys) })
    }
  }

  @Test func additionalCountrySearchSupportsNativeEnglishJapaneseAndOtherUILanguages()
    async throws
  {
    let cases: [(String, String, String)] = [
      ("ES", "Barcelona", "ES-08"),
      ("ES", "バルセロナ", "ES-08"),
      ("ES", "巴塞罗那", "ES-08"),
      ("ES", "바르셀로나", "ES-08"),
      ("KR", "서울", "KR-11"),
      ("KR", "Seoul", "KR-11"),
      ("KR", "ソウル", "KR-11"),
      ("KR", "慶州", "KR-47"),
      ("EG", "Cairo", "EG-C"),
      ("EG", "カイロ", "EG-C"),
      ("EG", "Abu Simbel", "EG-ASN"),
      ("TH", "Bangkok", "TH-10"),
      ("TH", "バンコク", "TH-10"),
      ("TH", "พัทยา", "TH-20"),
      ("TR", "İstanbul", "TR-34"),
      ("TR", "Istanbul", "TR-34"),
      ("TR", "イスタンブール", "TR-34"),
      ("TR", "Göreme", "TR-50"),
    ]
    var aliasesByCountry: [String: [PlaceSearchAlias]] = [:]
    for (countryCode, query, expectedCode) in cases {
      let aliases: [PlaceSearchAlias]
      if let cached = aliasesByCountry[countryCode] {
        aliases = cached
      } else {
        let definition = try #require(
          CountrySubdivisionRegistry.definition(for: countryCode)
        )
        let loaded = try await PlaceSearchIndexStore.load(
          resourceName: definition.searchIndexResourceName
        )
        aliasesByCountry[countryCode] = loaded
        aliases = loaded
      }
      #expect(PlaceSearchService.bestMatches(query: query, aliases: aliases)[expectedCode] != nil)
    }
    let turkey = try #require(aliasesByCountry["TR"])
    #expect(PlaceSearchService.bestMatches(query: "Cappadocia", aliases: turkey).count >= 4)

    let multilingualTargets = [
      "ES": "ES-08",
      "KR": "KR-11",
      "EG": "EG-C",
      "TH": "TH-10",
      "TR": "TR-34",
    ]
    for (countryCode, targetCode) in multilingualTargets {
      let definition = try #require(
        CountrySubdivisionRegistry.definition(for: countryCode)
      )
      let catalog = try await AdministrativeSubdivisionStore.load(
        resourceName: definition.catalogResourceName
      )
      let target = try #require(catalog.first { $0.id == targetCode })
      let aliases = try #require(aliasesByCountry[countryCode])
      for localizedName in target.localizedNames.values {
        #expect(
          PlaceSearchService.bestMatches(query: localizedName, aliases: aliases)[targetCode]
            != nil
        )
      }
    }
  }

  @Test func fourNewRegionSchemesHaveExpectedCountsAndValidSourceAssignments() async throws {
    let expected = ["US": 56, "MY": 16, "BE": 11, "SG": 8]
    for (countryCode, count) in expected {
      let scheme = try #require(CountryRegionSchemeRegistry.definition(for: countryCode))
      let catalog = try await AdministrativeSubdivisionStore.load(
        resourceName: scheme.recordableCatalogResourceName
      )
      let sourceUnits = try await AdministrativeSubdivisionStore.loadSourceUnits(
        resourceName: scheme.sourceCatalogResourceName
      )
      let geometry = try await AdministrativeSubdivisionStore.loadGeometry(
        resourceName: scheme.geometryResourceName
      )
      #expect(catalog.count == count)
      #expect(geometry.count == count)
      #expect(Set(catalog.map(\.id)) == Set(geometry.map(\.code)))
      try RegionSchemeValidator.validate(
        scheme: scheme,
        sourceUnits: sourceUnits,
        regions: catalog
      )
    }
    let singapore = try #require(CountryRegionSchemeRegistry.definition(for: "SG"))
    let planningAreas = try await AdministrativeSubdivisionStore.loadSourceUnits(
      resourceName: singapore.sourceCatalogResourceName
    )
    #expect(planningAreas.count == 55)
    #expect(Set(planningAreas.map(\.id)).count == 55)
  }

  @Test func newCountrySearchExamplesAndMultiRegionAliasesWork() async throws {
    let cases: [(String, String, Set<String>)] = [
      ("US", "Tumon", ["US-GU"]),
      ("US", "关岛", ["US-GU"]),
      ("US", "Saipan", ["US-MP"]),
      ("US", "Honolulu", ["US-HI"]),
      ("US", "Yellowstone", ["US-WY", "US-MT", "US-ID"]),
      ("MY", "George Town", ["MY-07"]),
      ("MY", "Langkawi", ["MY-02"]),
      ("MY", "Kota Kinabalu", ["MY-12"]),
      ("BE", "Bruxelles", ["BE-BRU"]),
      ("BE", "Brussel", ["BE-BRU"]),
      ("BE", "Bruges", ["BE-VWV"]),
      ("BE", "Ghent", ["BE-VOV"]),
      ("SG", "Marina Bay", ["SG-CV-DOWNTOWN"]),
      ("SG", "濱海灣", ["SG-CV-DOWNTOWN"]),
      ("SG", "Sentosa", ["SG-CV-SOUTH"]),
      ("SG", "Changi Airport", ["SG-CV-CHANGI"]),
      ("SG", "Aéroport de Changi", ["SG-CV-CHANGI"]),
      ("SG", "Night Safari", ["SG-CV-NORTH"]),
      ("SG", "Jurong", ["SG-CV-WEST"]),
    ]
    var cache: [String: [PlaceSearchAlias]] = [:]
    for (countryCode, query, expectedRegions) in cases {
      let aliases: [PlaceSearchAlias]
      if let loaded = cache[countryCode] {
        aliases = loaded
      } else {
        let scheme = try #require(CountryRegionSchemeRegistry.definition(for: countryCode))
        let loaded = try await PlaceSearchIndexStore.load(
          resourceName: scheme.searchIndexResourceName
        )
        cache[countryCode] = loaded
        aliases = loaded
      }
      let matches = PlaceSearchService.bestMatches(query: query, aliases: aliases)
      #expect(expectedRegions.isSubset(of: matches.keys))
    }
  }

  @Test func compositeRegionSemanticsMatchCountrySpecifications() async throws {
    let us = try await AdministrativeSubdivisionStore.load(resourceName: "us-subdivisions")
    #expect(us.filter { $0.semanticType == .territory }.count == 5)
    #expect(us.filter { $0.semanticType == .administrative }.count == 51)
    #expect(us.contains { $0.id == "US-GU" })

    let malaysia = try await AdministrativeSubdivisionStore.load(
      resourceName: "my-subdivisions"
    )
    #expect(malaysia.filter { $0.groupCode == "states" }.count == 13)
    #expect(malaysia.filter { $0.groupCode == "federal-territories" }.count == 3)

    let belgium = try await AdministrativeSubdivisionStore.load(
      resourceName: "be-subdivisions"
    )
    #expect(belgium.filter { $0.id != "BE-BRU" }.count == 10)
    #expect(belgium.contains { $0.id == "BE-BRU" })
    #expect(!belgium.contains { ["Flemish Region", "Walloon Region"].contains($0.nativeName) })
  }

  @Test func regionSchemeValidatorDetectsDuplicateAndMissingSources() throws {
    let scheme = CountryRegionScheme(
      countryCode: "ZZ",
      kind: .travelArea,
      unitLabelKey: "Areas",
      sourceCatalogResourceName: "source",
      recordableCatalogResourceName: "regions",
      geometryResourceName: "map",
      searchIndexResourceName: "search",
      mapInsets: [],
      listGroups: [],
      expectedRegionCount: 2
    )
    let sources = [
      RegionSourceUnit(
        id: "ZZ-A",
        countryCode: "ZZ",
        sourceCode: "A",
        sourceLevel: "test",
        geometryResourceID: "A"
      ),
      RegionSourceUnit(
        id: "ZZ-B",
        countryCode: "ZZ",
        sourceCode: "B",
        sourceLevel: "test",
        geometryResourceID: "B"
      ),
    ]
    let regions = [
      RecordableRegion(
        id: "ZZ-1",
        countryCode: "ZZ",
        code: "1",
        nativeName: "One",
        localizedNames: ["en": "One"],
        sourceUnitIDs: ["ZZ-A"],
        groupCode: "",
        localizedGroupNames: [:],
        displayOrder: 0,
        semanticType: .travelArea
      ),
      RecordableRegion(
        id: "ZZ-2",
        countryCode: "ZZ",
        code: "2",
        nativeName: "Two",
        localizedNames: ["en": "Two"],
        sourceUnitIDs: ["ZZ-A"],
        groupCode: "",
        localizedGroupNames: [:],
        displayOrder: 1,
        semanticType: .travelArea
      ),
    ]
    #expect(throws: RegionSchemeValidationError.duplicateSourceUnits(["ZZ-A"])) {
      try RegionSchemeValidator.validate(scheme: scheme, sourceUnits: sources, regions: regions)
    }
  }

  @MainActor
  @Test func regionSelectionRequiresVisitedParentAndNeverAutoVisitsIt() async {
    let repository = MemoryVisitStateRepository()
    let state = AppState(defaults: testDefaults(), repository: repository)
    await state.load()

    await state.setPrefectureVisited(true, prefectureCode: "JP-26")
    #expect(!state.visitedCodes.contains("JP"))
    #expect(state.visitedPrefectureCodes.isEmpty)

    await state.setVisited(true, countryCode: "JP")
    await state.setPrefectureVisited(true, prefectureCode: "JP-26")
    #expect(state.visitedCodes.contains("JP"))
    #expect(state.visitedPrefectureCodes == ["JP-26"])
    #expect(state.visitedCountryCount == 1)
  }

  @MainActor
  @Test func removingJapanAlsoRemovesAllPrefectures() async {
    let repository = MemoryVisitStateRepository()
    let state = AppState(defaults: testDefaults(), repository: repository)
    await state.load()
    await state.setVisited(true, countryCode: "JP")
    await state.setPrefectureVisited(true, prefectureCode: "JP-13")
    await state.setPrefectureVisited(true, prefectureCode: "JP-27")

    await state.setVisited(false, countryCode: "JP")

    #expect(!state.visitedCodes.contains("JP"))
    #expect(state.visitedPrefectureCodes.isEmpty)
  }

  @MainActor
  @Test func removingLastPrefectureDoesNotRemoveJapan() async {
    let repository = MemoryVisitStateRepository()
    let state = AppState(defaults: testDefaults(), repository: repository)
    await state.load()
    await state.setVisited(true, countryCode: "JP")
    await state.setPrefectureVisited(true, prefectureCode: "JP-01")

    await state.setPrefectureVisited(false, prefectureCode: "JP-01")

    #expect(state.visitedCodes.contains("JP"))
    #expect(state.visitedPrefectureCodes.isEmpty)
  }

  @MainActor
  @Test func completingPrefectureSelectionReplacesAllPrefecturesAndVisitsJapan() async {
    let repository = MemoryVisitStateRepository()
    let state = AppState(defaults: testDefaults(), repository: repository)
    await state.load()
    await state.setVisited(true, countryCode: "JP")
    await state.setPrefectureVisited(true, prefectureCode: "JP-01")

    await state.replaceVisitedPrefectures(with: ["JP-13", "JP-26"])

    #expect(state.visitedPrefectureCodes == ["JP-13", "JP-26"])
    #expect(state.visitedCodes.contains("JP"))
  }

  @MainActor
  @Test func franceDepartmentSelectionMaintainsCountryInvariants() async {
    let repository = MemoryVisitStateRepository()
    let state = AppState(defaults: testDefaults(), repository: repository)
    await state.load()

    await state.setVisited(true, countryCode: "FR")
    await state.replaceVisitedFranceDepartments(with: ["FR-75", "FR-06"])
    #expect(state.visitedCodes.contains("FR"))
    #expect(state.visitedFranceDepartmentCodes == ["FR-75", "FR-06"])
    #expect(state.visitedCountryCount == 1)

    await state.replaceVisitedFranceDepartments(with: [])
    #expect(state.visitedCodes.contains("FR"))

    await state.setVisited(false, countryCode: "FR")
    #expect(state.visitedFranceDepartmentCodes.isEmpty)
  }

  @MainActor
  @Test func additionalCountrySubdivisionSelectionMaintainsCountryInvariants() async {
    let state = AppState(
      defaults: testDefaults(),
      repository: MemoryVisitStateRepository()
    )
    await state.load()

    await state.setVisited(true, countryCode: "ES")
    await state.replaceVisitedSubdivisions(countryCode: "ES", with: ["ES-08"])
    #expect(state.visitedCodes.contains("ES"))
    #expect(state.visitedSubdivisionCodes(countryCode: "ES") == ["ES-08"])
    #expect(state.visitedCountryCount == 1)

    await state.replaceVisitedSubdivisions(countryCode: "ES", with: [])
    #expect(state.visitedCodes.contains("ES"))

    await state.setVisited(false, countryCode: "ES")
    #expect(state.visitedSubdivisionCodes(countryCode: "ES").isEmpty)
  }

  @MainActor
  @Test func jsonExportAndImportPreserveCountryAndSubdivisionVisits() async throws {
    let source = AppState(defaults: testDefaults(), repository: MemoryVisitStateRepository())
    await source.load()
    await source.setVisited(true, countryCode: "JP")
    await source.setVisited(true, countryCode: "FR")
    await source.replaceVisitedPrefectures(with: ["JP-28"])
    await source.replaceVisitedFranceDepartments(with: ["FR-75"])
    let exported = try source.exportedVisitData()

    let destination = AppState(defaults: testDefaults(), repository: MemoryVisitStateRepository())
    await destination.load()
    try await destination.importVisitData(exported)

    #expect(destination.visitedCodes.contains("JP"))
    #expect(destination.visitedCodes.contains("FR"))
    #expect(destination.visitedPrefectureCodes == ["JP-28"])
    #expect(destination.visitedFranceDepartmentCodes == ["FR-75"])
  }

  @MainActor
  @Test func inconsistentImportRequiresAnExplicitParentDecision() async throws {
    let imported = VisitData(
      countryStates: [
        CountryVisitState(countryCode: "US", isVisited: false, updatedAt: .now)
      ],
      regionStates: [
        RegionVisitState(
          countryCode: "US",
          regionID: "US-GU",
          isVisited: true,
          updatedAt: .now
        )
      ]
    )
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let data = try encoder.encode(imported)
    let state = AppState(defaults: testDefaults(), repository: MemoryVisitStateRepository())
    await state.load()

    await #expect(throws: VisitDataImportError.unvisitedParentCountries(["US"])) {
      try await state.importVisitData(data)
    }
    try await state.importVisitData(data, repairUnvisitedParents: false)
    #expect(!state.visitedCodes.contains("US"))
    #expect(state.visitedSubdivisionCodes(countryCode: "US").isEmpty)
    try await state.importVisitData(data, repairUnvisitedParents: true)
    #expect(state.visitedCodes.contains("US"))
    #expect(state.visitedSubdivisionCodes(countryCode: "US") == ["US-GU"])
  }

  @Test func legacyCountryArrayMigratesWithoutLosingVisits() throws {
    let legacy = [
      CountryVisitState(countryCode: "JP", isVisited: true, updatedAt: .distantPast),
      CountryVisitState(countryCode: "FR", isVisited: false, updatedAt: .distantPast),
    ]
    let data = try JSONEncoder().encode(legacy)

    let migrated = try FileVisitStateRepository.decode(data)

    #expect(migrated.countryStates == legacy)
    #expect(migrated.visitedPrefectureCodes.isEmpty)
  }

  @Test func versionTwoJapanDataMigratesIntoVersionFiveRegions() throws {
    let data = Data(
      """
      {
        "version": 2,
        "countryStates": [],
        "visitedPrefectureCodes": ["JP-13", "JP-28"]
      }
      """.utf8
    )

    let migrated = try FileVisitStateRepository.decode(data)

    #expect(migrated.version == 5)
    #expect(migrated.visitedPrefectureCodes == ["JP-13", "JP-28"])
    #expect(migrated.subdivisionCodesByCountry["FR"] == nil)
  }

  @Test func versionThreeJapanAndFranceDataMigrateIntoVersionFive() throws {
    let data = Data(
      """
      {
        "formatVersion": 3,
        "countries": [],
        "subdivisionCodesByCountry": {
          "JP": ["JP-13"],
          "FR": ["FR-75"]
        }
      }
      """.utf8
    )

    let migrated = try FileVisitStateRepository.decode(data)

    #expect(migrated.version == 5)
    #expect(migrated.subdivisionCodesByCountry["JP"] == ["JP-13"])
    #expect(migrated.subdivisionCodesByCountry["FR"] == ["FR-75"])
  }

  @Test func resetClearsCountriesRegionsAndPersistedData() async throws {
    let repository = MemoryVisitStateRepository()
    let state = await AppState(defaults: testDefaults(), repository: repository)
    await state.load()
    await state.setVisited(true, countryCode: "JP")
    await state.replaceVisitedPrefectures(with: ["JP-13"])

    await state.resetAllData()

    #expect(await state.visitedCodes.isEmpty)
    #expect(await state.visitedPrefectureCodes.isEmpty)
    let persisted = await repository.snapshot()
    #expect(persisted.countryStates.isEmpty)
    #expect(persisted.regionStates.isEmpty)
  }

  @Test func externalServicesAreSafeWhenDisabledAndIDsAreMissing() async {
    let configuration = AppConfiguration(
      adsEnabled: false,
      cloudSyncEnabled: false,
      admobAppID: " ",
      bannerAdUnitID: nil,
      privacyPolicyURL: URL(string: "https://tmkch.io/privacy")!,
      termsURL: URL(string: "https://tmkch.io/terms")!,
      supportURL: URL(string: "https://tmkch.io/support")!,
      marketingURL: URL(string: "https://tmkch.io/apps/colorvia")!
    )
    let service = DisabledAdService()

    await service.initialize()

    #expect(!configuration.adsEnabled)
    #expect(!configuration.cloudSyncEnabled)
    #expect(configuration.admobAppID == nil)
    #expect(!configuration.hasCompleteAdMobConfiguration)
    #expect(await !service.canShowAds)
  }

  @Test func productionAdsStayOffWhenConsentIsNotGranted() async {
    let configuration = Self.adsEnabledConfiguration
    let consent = await FakeConsentGatherer(canRequestAds: false)
    let tracking = await FakeTrackingAuthorizationProvider()
    let service = await ProductionAdMobService(
      configuration: configuration,
      trackingAuthorization: tracking,
      consent: consent
    )

    await service.initialize()

    #expect(await consent.gatherCallCount == 1)
    #expect(await tracking.requestCallCount == 1)
    #expect(await !service.canShowAds)
  }

  @Test func productionAdsNeverAskForConsentWhileAdsAreDisabled() async {
    let consent = await FakeConsentGatherer(canRequestAds: true)
    let tracking = await FakeTrackingAuthorizationProvider()
    let service = await ProductionAdMobService(
      configuration: Self.adsDisabledConfiguration,
      trackingAuthorization: tracking,
      consent: consent
    )

    await service.initialize()

    #expect(await consent.gatherCallCount == 0)
    #expect(await tracking.requestCallCount == 0)
    #expect(await !service.canShowAds)
  }

  private static var adsEnabledConfiguration: AppConfiguration {
    AppConfiguration(
      adsEnabled: true,
      cloudSyncEnabled: false,
      admobAppID: "ca-app-pub-0000000000000000~0000000000",
      bannerAdUnitID: "ca-app-pub-0000000000000000/0000000000",
      privacyPolicyURL: URL(string: "https://colorvia.tmkch.io/privacy")!,
      termsURL: URL(string: "https://colorvia.tmkch.io/terms")!,
      supportURL: URL(string: "https://tmkch.io/support")!,
      marketingURL: URL(string: "https://colorvia.tmkch.io")!
    )
  }

  private static var adsDisabledConfiguration: AppConfiguration {
    AppConfiguration(
      adsEnabled: false,
      cloudSyncEnabled: false,
      admobAppID: "ca-app-pub-0000000000000000~0000000000",
      bannerAdUnitID: "ca-app-pub-0000000000000000/0000000000",
      privacyPolicyURL: URL(string: "https://colorvia.tmkch.io/privacy")!,
      termsURL: URL(string: "https://colorvia.tmkch.io/terms")!,
      supportURL: URL(string: "https://tmkch.io/support")!,
      marketingURL: URL(string: "https://colorvia.tmkch.io")!
    )
  }

  @Test func legalDocumentsUseJapaneseOnlyForJapaneseAndEnglishOtherwise() {
    let privacyURL = URL(string: "https://colorvia.tmkch.io/privacy")!

    #expect(
      localizedLegalText(english: "Privacy", japanese: "プライバシー", language: "ja-JP")
        == "プライバシー"
    )
    #expect(
      localizedLegalText(english: "Privacy", japanese: "プライバシー", language: "fr")
        == "Privacy"
    )
    #expect(
      localizedLegalURL(privacyURL, language: "ja")
        == URL(string: "https://colorvia.tmkch.io/ja/privacy")
    )
    #expect(localizedLegalURL(privacyURL, language: "en") == privacyURL)
    #expect(localizedLegalURL(privacyURL, language: "ko") == privacyURL)
  }

  @Test func iCloudConflictResolverChoosesTheNewerSnapshot() {
    let older = Date(timeIntervalSince1970: 100)
    let newer = Date(timeIntervalSince1970: 200)

    #expect(
      VisitDataConflictResolver.cloudWins(localUpdatedAt: older, cloudUpdatedAt: newer)
    )
    #expect(
      !VisitDataConflictResolver.cloudWins(localUpdatedAt: newer, cloudUpdatedAt: older)
    )
    #expect(
      VisitDataConflictResolver.cloudWins(localUpdatedAt: nil, cloudUpdatedAt: older)
    )
  }

  @Test func iCloudMergeResolvesEachRegionByTimestampWithoutSetUnion() {
    let local = VisitData(
      countryStates: [
        CountryVisitState(
          countryCode: "US",
          isVisited: true,
          updatedAt: Date(timeIntervalSince1970: 100)
        )
      ],
      regionStates: [
        RegionVisitState(
          countryCode: "US",
          regionID: "US-GU",
          isVisited: true,
          updatedAt: Date(timeIntervalSince1970: 100)
        )
      ]
    )
    let cloud = VisitData(
      countryStates: [
        CountryVisitState(
          countryCode: "US",
          isVisited: true,
          updatedAt: Date(timeIntervalSince1970: 200)
        )
      ],
      regionStates: [
        RegionVisitState(
          countryCode: "US",
          regionID: "US-GU",
          isVisited: false,
          updatedAt: Date(timeIntervalSince1970: 300)
        )
      ]
    )

    let merged = FileVisitStateRepository.merge(local: local, cloud: cloud)
    #expect(merged.regionStates.first { $0.regionID == "US-GU" }?.isVisited == false)
  }

  private func testDefaults() -> UserDefaults {
    let suiteName = "ColorviaTests.\(UUID().uuidString)"
    return UserDefaults(suiteName: suiteName)!
  }
}

@MainActor
private final class FakeConsentGatherer: ConsentGathering {
  let canRequestAds: Bool
  var isPrivacyOptionsRequired = false
  private(set) var gatherCallCount = 0
  private(set) var privacyOptionsCallCount = 0

  init(canRequestAds: Bool) {
    self.canRequestAds = canRequestAds
  }

  func gatherIfNeeded() async {
    gatherCallCount += 1
  }

  func presentPrivacyOptions() async {
    privacyOptionsCallCount += 1
  }
}

@MainActor
private final class FakeTrackingAuthorizationProvider: TrackingAuthorizationProviding {
  private(set) var requestCallCount = 0

  func requestIfNeeded() async {
    requestCallCount += 1
  }
}

private actor MemoryVisitStateRepository: VisitStateRepository {
  private var data = VisitData()

  func loadData() async throws -> VisitData {
    data
  }

  func saveData(_ data: VisitData) async throws {
    self.data = data
  }

  func snapshot() -> VisitData {
    data
  }
}
