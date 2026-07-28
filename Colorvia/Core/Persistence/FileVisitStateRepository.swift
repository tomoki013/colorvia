import Foundation

protocol VisitStateRepository: Sendable {
  func loadData() async throws -> VisitData
  func saveData(_ data: VisitData) async throws
}

enum VisitDataConflictResolver {
  static func cloudWins(localUpdatedAt: Date?, cloudUpdatedAt: Date) -> Bool {
    guard let localUpdatedAt else { return true }
    return cloudUpdatedAt > localUpdatedAt
  }
}

actor FileVisitStateRepository: VisitStateRepository {
  private let fileManager = FileManager.default
  private let cloudStore = NSUbiquitousKeyValueStore.default
  private static let cloudDataKey = "visit-states-v5"
  private static let cloudTimestampKey = "visit-states-v5-updated-at"
  private static let legacyCloudDataKey = "visit-states-v3"
  private static let legacyCloudTimestampKey = "visit-states-v3-updated-at"
  private static let v4CloudDataKey = "visit-states-v4"
  private static let v4CloudTimestampKey = "visit-states-v4-updated-at"
  private static let regionCountryCodes = [
    "JP", "FR", "ES", "KR", "EG", "TH", "TR", "US", "MY", "BE", "SG",
  ]

  private var fileURL: URL {
    get throws {
      let directory = try fileManager.url(
        for: .applicationSupportDirectory,
        in: .userDomainMask,
        appropriateFor: nil,
        create: true
      ).appending(path: "Colorvia", directoryHint: .isDirectory)
      try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
      return directory.appending(path: "visit-states.json")
    }
  }

  func loadData() async throws -> VisitData {
    let url = try fileURL
    let localSnapshot: (data: Data, timestamp: Date)? =
      if fileManager.fileExists(atPath: url.path) {
        (
          try Data(contentsOf: url),
          (try? url.resourceValues(forKeys: [.contentModificationDateKey])
            .contentModificationDate) ?? .distantPast
        )
      } else {
        nil
      }

    cloudStore.synchronize()
    let cloudData =
      cloudStore.data(forKey: Self.cloudDataKey)
      ?? cloudStore.data(forKey: Self.v4CloudDataKey)
      ?? cloudStore.data(forKey: Self.legacyCloudDataKey)
    let cloudTimestamp = Date(
      timeIntervalSince1970: max(
        cloudStore.double(forKey: Self.cloudTimestampKey),
        max(
          cloudStore.double(forKey: Self.v4CloudTimestampKey),
          cloudStore.double(forKey: Self.legacyCloudTimestampKey)
        )
      )
    )

    let local = try localSnapshot.map { snapshot in
      if Self.formatVersion(of: snapshot.data) < 5 {
        try backupBeforeMigration(snapshot.data)
      }
      return try Self.decode(snapshot.data)
    }
    var cloud = try cloudData.map(Self.decode)
    let perCountryRegions = loadPerCountryRegionStates()
    if !perCountryRegions.isEmpty {
      var snapshot = cloud ?? VisitData()
      snapshot.regionStates = Self.mergeRegionStates(snapshot.regionStates, perCountryRegions)
      cloud = snapshot
    }

    let merged =
      if let local, let cloud {
        Self.merge(local: local, cloud: cloud)
      } else {
        local ?? cloud ?? VisitData()
      }
    let encoder = Self.encoder()
    let mergedData = try encoder.encode(merged)
    try mergedData.write(to: url, options: [.atomic])
    if cloudData == nil || (localSnapshot?.timestamp ?? .distantPast) > cloudTimestamp {
      publishToCloud(mergedData, visitData: merged, updatedAt: Date())
    }
    return merged
  }

  nonisolated static func decode(_ data: Data) throws -> VisitData {
    for strategy in [
      JSONDecoder.DateDecodingStrategy.deferredToDate,
      JSONDecoder.DateDecodingStrategy.iso8601,
    ] {
      let decoder = JSONDecoder()
      decoder.dateDecodingStrategy = strategy
      if let current = try? decoder.decode(VisitData.self, from: data) {
        return current
      }
    }
    // Version 1 stored a bare array. Keep existing users' country selections.
    for strategy in [
      JSONDecoder.DateDecodingStrategy.deferredToDate,
      JSONDecoder.DateDecodingStrategy.iso8601,
    ] {
      let decoder = JSONDecoder()
      decoder.dateDecodingStrategy = strategy
      if let legacyStates = try? decoder.decode([CountryVisitState].self, from: data) {
        return VisitData(countryStates: legacyStates)
      }
    }
    throw CocoaError(.coderReadCorrupt)
  }

  func saveData(_ visitData: VisitData) async throws {
    let encoder = Self.encoder()
    let data = try encoder.encode(visitData)
    try data.write(to: fileURL, options: [.atomic])
    publishToCloud(data, visitData: visitData, updatedAt: Date())
  }

  private func publishToCloud(_ data: Data, visitData: VisitData, updatedAt: Date) {
    cloudStore.set(data, forKey: Self.cloudDataKey)
    cloudStore.set(updatedAt.timeIntervalSince1970, forKey: Self.cloudTimestampKey)
    let encoder = Self.encoder()
    for countryCode in Self.regionCountryCodes {
      let states = visitData.regionStates.filter { $0.countryCode == countryCode }
      if let encoded = try? encoder.encode(states) {
        cloudStore.set(encoded, forKey: "colorvia.visit.regions.\(countryCode.lowercased())")
      }
    }
    cloudStore.synchronize()
  }

  private func loadPerCountryRegionStates() -> [RegionVisitState] {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return Self.regionCountryCodes.flatMap { countryCode -> [RegionVisitState] in
      guard
        let data = cloudStore.data(
          forKey: "colorvia.visit.regions.\(countryCode.lowercased())"
        )
      else { return [RegionVisitState]() }
      return (try? decoder.decode([RegionVisitState].self, from: data)) ?? []
    }
  }

  private func backupBeforeMigration(_ data: Data) throws {
    let backupURL = try fileURL.deletingLastPathComponent()
      .appending(path: "visit-states-v4-backup.json")
    guard !fileManager.fileExists(atPath: backupURL.path) else { return }
    guard fileManager.createFile(atPath: backupURL.path, contents: data) else {
      // Another process may have completed the same one-time migration.
      guard fileManager.fileExists(atPath: backupURL.path) else {
        throw CocoaError(.fileWriteUnknown)
      }
      return
    }
  }

  nonisolated private static func formatVersion(of data: Data) -> Int {
    guard
      let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    else { return 1 }
    return object["formatVersion"] as? Int ?? object["version"] as? Int ?? 1
  }

  nonisolated private static func encoder() -> JSONEncoder {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    return encoder
  }

  nonisolated static func merge(local: VisitData, cloud: VisitData) -> VisitData {
    let countries = mergeCountryStates(local.countryStates, cloud.countryStates)
    var regions = mergeRegionStates(local.regionStates, cloud.regionStates)
    let countriesByCode = Dictionary(
      uniqueKeysWithValues: countries.map { ($0.countryCode, $0) }
    )
    regions = regions.map { region in
      guard
        region.isVisited,
        let parent = countriesByCode[region.countryCode],
        !parent.isVisited
      else { return region }
      return RegionVisitState(
        countryCode: region.countryCode,
        regionID: region.regionID,
        isVisited: false,
        updatedAt: max(parent.updatedAt, region.updatedAt)
      )
    }
    return VisitData(countryStates: countries, regionStates: regions)
  }

  nonisolated private static func mergeCountryStates(
    _ lhs: [CountryVisitState],
    _ rhs: [CountryVisitState]
  ) -> [CountryVisitState] {
    var result = Dictionary(uniqueKeysWithValues: lhs.map { ($0.countryCode, $0) })
    for state in rhs where state.updatedAt > result[state.countryCode]?.updatedAt ?? .distantPast {
      result[state.countryCode] = state
    }
    return result.values.sorted { $0.countryCode < $1.countryCode }
  }

  nonisolated private static func mergeRegionStates(
    _ lhs: [RegionVisitState],
    _ rhs: [RegionVisitState]
  ) -> [RegionVisitState] {
    var result = Dictionary(
      uniqueKeysWithValues: lhs.map { ("\($0.countryCode)|\($0.regionID)", $0) }
    )
    for state in rhs {
      let key = "\(state.countryCode)|\(state.regionID)"
      if state.updatedAt > result[key]?.updatedAt ?? .distantPast {
        result[key] = state
      }
    }
    return result.values.sorted {
      ($0.countryCode, $0.regionID) < ($1.countryCode, $1.regionID)
    }
  }
}
