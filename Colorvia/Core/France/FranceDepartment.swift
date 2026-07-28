import Foundation

struct FranceDepartment: Identifiable, Codable, Hashable, Sendable {
  let id: String
  let code: String
  let nativeName: String
  let localizedNames: [String: String]?
  let groupCode: String
  let groupName: String
  let displayOrder: Int

  var localizedName: String {
    localizedNames?[Locale.current.language.languageCode?.identifier ?? "en"]
      ?? localizedNames?["en"]
      ?? nativeName
  }

  var searchableText: String {
    [nativeName, code, id]
      .joined(separator: " ")
      .folding(
        options: [.caseInsensitive, .widthInsensitive, .diacriticInsensitive],
        locale: .current
      )
      .lowercased()
  }
}

enum FranceDepartmentStore {
  static func load() async throws -> [FranceDepartment] {
    guard
      let url = Bundle.main.url(
        forResource: "france-departments",
        withExtension: "json"
      )
    else {
      throw CocoaError(.fileNoSuchFile)
    }
    let data = try Data(contentsOf: url)
    return try JSONDecoder().decode([FranceDepartment].self, from: data)
  }
}

enum FranceMapStore {
  static func load() async throws -> [MapPrefecture] {
    guard let url = Bundle.main.url(forResource: "france-map", withExtension: "json")
    else {
      throw CocoaError(.fileNoSuchFile)
    }
    let data = try Data(contentsOf: url)
    return try JSONDecoder().decode([MapPrefecture].self, from: data)
  }
}
