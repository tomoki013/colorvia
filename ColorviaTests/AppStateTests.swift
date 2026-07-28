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
}
