import Foundation

struct MapPoint: Codable, Hashable, Sendable {
  let x: Double
  let y: Double
}

struct MapCountry: Codable, Identifiable, Hashable, Sendable {
  var id: String { code }
  let code: String
  let polygons: [[MapPoint]]
}

enum WorldMapStore {
  static func load() async throws -> [MapCountry] {
    guard let url = Bundle.main.url(forResource: "world-map", withExtension: "json") else {
      throw CocoaError(.fileNoSuchFile)
    }
    let data = try Data(contentsOf: url)
    return try JSONDecoder().decode([MapCountry].self, from: data)
  }
}
