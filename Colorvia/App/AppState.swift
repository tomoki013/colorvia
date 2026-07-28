import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class AppState {
  private(set) var countries: [Country] = []
  private(set) var mapCountries: [MapCountry] = []
  private(set) var visitedCodes: Set<String> = []
  private(set) var isLoading = true
  var hasCompletedOnboarding: Bool
  var appearance: AppearancePreference
  var mapColor: MapColorPreference
  var lastError: String?

  private let repository = FileVisitStateRepository()
  private let defaults: UserDefaults

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
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
      async let states = repository.loadStates()
      countries = try await loadedCountries
      mapCountries = try await loadedMap
      visitedCodes = Set(try await states.filter(\.isVisited).map(\.countryCode))
    } catch {
      lastError = error.localizedDescription
    }
    isLoading = false
  }

  func completeOnboarding(with codes: Set<String>) async {
    visitedCodes = codes
    hasCompletedOnboarding = true
    defaults.set(true, forKey: PreferenceKeys.onboardingCompleted)
    await persist()
  }

  func setVisited(_ visited: Bool, countryCode: String) async {
    if visited {
      visitedCodes.insert(countryCode)
    } else {
      visitedCodes.remove(countryCode)
    }
    await persist()
  }

  func replaceVisitedCountries(with codes: Set<String>) async {
    visitedCodes = codes
    await persist()
  }

  func resetAllData() async {
    visitedCodes.removeAll()
    hasCompletedOnboarding = false
    defaults.set(false, forKey: PreferenceKeys.onboardingCompleted)
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

  func visitedCount(in continent: Continent) -> Int {
    countries.lazy.filter { $0.continent == continent && self.visitedCodes.contains($0.id) }.count
  }

  private func persist() async {
    let now = Date()
    let states = countries.map {
      CountryVisitState(countryCode: $0.id, isVisited: visitedCodes.contains($0.id), updatedAt: now)
    }
    do {
      try await repository.saveStates(states)
    } catch {
      lastError = error.localizedDescription
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
