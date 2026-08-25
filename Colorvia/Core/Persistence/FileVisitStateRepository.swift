import Foundation

protocol VisitStateRepository: Sendable {
  func loadData() async throws -> VisitData
  func saveData(_ data: VisitData) async throws
  func resetData() async throws
}

extension VisitStateRepository {
  func resetData() async throws {
    try await saveData(VisitData())
  }
}

enum VisitDataConflictResolver {
  static func cloudWins(localUpdatedAt: Date?, cloudUpdatedAt: Date) -> Bool {
    guard let localUpdatedAt else { return true }
    return cloudUpdatedAt > localUpdatedAt
  }
}

actor FileVisitStateRepository: VisitStateRepository {
  private let fileManager = FileManager.default

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
    guard fileManager.fileExists(atPath: url.path) else { return VisitData() }

    let data = try Data(contentsOf: url)
    if Self.formatVersion(of: data) < 5 {
      try backupBeforeMigration(data)
    }
    do {
      return try Self.decode(data)
    } catch {
      try quarantineCorruptData(data)
      return VisitData()
    }
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
  }

  func resetData() async throws {
    let url = try fileURL
    guard fileManager.fileExists(atPath: url.path) else { return }
    try fileManager.removeItem(at: url)
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

  private func quarantineCorruptData(_ data: Data) throws {
    let corruptURL = try fileURL.deletingLastPathComponent()
      .appending(path: "visit-states-corrupt-backup.json")
    guard !fileManager.fileExists(atPath: corruptURL.path) else { return }
    guard fileManager.createFile(atPath: corruptURL.path, contents: data) else {
      throw CocoaError(.fileWriteUnknown)
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
