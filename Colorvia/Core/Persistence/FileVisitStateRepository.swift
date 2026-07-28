import Foundation

protocol VisitStateRepository: Sendable {
  func loadStates() async throws -> [CountryVisitState]
  func saveStates(_ states: [CountryVisitState]) async throws
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

  func loadStates() async throws -> [CountryVisitState] {
    let url = try fileURL
    guard fileManager.fileExists(atPath: url.path) else { return [] }
    let data = try Data(contentsOf: url)
    return try JSONDecoder().decode([CountryVisitState].self, from: data)
  }

  func saveStates(_ states: [CountryVisitState]) async throws {
    let data = try JSONEncoder().encode(states)
    try data.write(to: fileURL, options: [.atomic])
  }
}
