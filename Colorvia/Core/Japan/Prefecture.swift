import Foundation

struct Prefecture: Identifiable, Codable, Hashable, Sendable {
  let id: String
  let englishName: String
  let japaneseName: String
  let region: JapanRegion

  var localizedName: String {
    Locale.current.language.languageCode?.identifier == "ja" ? japaneseName : englishName
  }

  var searchableText: String {
    [japaneseName, englishName, id]
      .joined(separator: " ")
      .folding(
        options: [.caseInsensitive, .widthInsensitive, .diacriticInsensitive],
        locale: .current
      )
      .lowercased()
  }
}

enum JapanRegion: String, Codable, CaseIterable, Sendable {
  case hokkaido
  case tohoku
  case kanto
  case chubu
  case kinki
  case chugoku
  case shikoku
  case kyushuOkinawa

  var localizedName: String {
    switch self {
    case .hokkaido: L10n.text("region.hokkaido")
    case .tohoku: L10n.text("region.tohoku")
    case .kanto: L10n.text("region.kanto")
    case .chubu: L10n.text("region.chubu")
    case .kinki: L10n.text("region.kinki")
    case .chugoku: L10n.text("region.chugoku")
    case .shikoku: L10n.text("region.shikoku")
    case .kyushuOkinawa: L10n.text("region.kyushu_okinawa")
    }
  }
}

enum PrefectureCatalog {
  static func load() async throws -> [Prefecture] {
    guard let url = Bundle.main.url(forResource: "prefectures", withExtension: "json") else {
      throw CocoaError(.fileNoSuchFile)
    }
    let data = try Data(contentsOf: url)
    return try JSONDecoder().decode([Prefecture].self, from: data)
  }
}
