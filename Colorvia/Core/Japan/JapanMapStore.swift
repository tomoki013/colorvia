import Foundation

struct MapPrefecture: Codable, Identifiable, Hashable, Sendable {
  var id: String { code }
  let code: String
  let polygons: [[MapPoint]]
}

enum JapanMapStore {
  static func load() async throws -> [MapPrefecture] {
    guard let url = Bundle.main.url(forResource: "japan-map", withExtension: "json") else {
      throw CocoaError(.fileNoSuchFile)
    }
    let data = try Data(contentsOf: url)
    return try JSONDecoder().decode([MapPrefecture].self, from: data)
  }
}
