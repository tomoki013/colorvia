import SwiftUI
import UIKit

struct HomeView: View {
  @Environment(AppState.self) private var appState
  @State private var path: [AppRoute] = []
  @State private var showingPicker = false
  @State private var showingSettings = false
  @State private var isStatisticsExpanded = false

  /// Screen-based gate so showing the banner cannot flip this decision and loop.
  private var isBannerLayoutAllowed: Bool {
    // iPhone SE-class heights leave too little map after sheet + 50pt banner.
    UIScreen.main.bounds.height >= 700
  }

  var body: some View {
    NavigationStack(path: $path) {
      GeometryReader { proxy in
        let collapsedHeight: CGFloat = 168
        let expandedHeight = min(proxy.size.height * 0.78, 660)

        ZStack(alignment: .bottomTrailing) {
          VStack(spacing: 0) {
            header

            WorldMapView(
              countries: appState.mapCountries,
              visitedCodes: appState.visitedCodes,
              visitedColor: appState.mapColor.color
            )
            .padding(.horizontal, 14)
            .padding(.top, 6)
            .padding(.bottom, collapsedHeight - 22)
          }

          if !isStatisticsExpanded {
            addButton
              .padding(.trailing, 25)
              .padding(.bottom, collapsedHeight + 16)
              .transition(.scale(scale: 0.8).combined(with: .opacity))
          }

          StatisticsBottomSheet(
            isExpanded: $isStatisticsExpanded,
            collapsedHeight: collapsedHeight,
            expandedHeight: expandedHeight
          )
          .environment(appState)
          .animation(.snappy(duration: 0.26), value: isStatisticsExpanded)
        }
      }
      .background(ColorviaTheme.background.ignoresSafeArea())
      .safeAreaInset(edge: .bottom, spacing: 0) {
        // Sits under the map / statistics sheet (including the expanded
        // visited-country list). Never overlays the map or floating controls.
        BannerAdContainer(isEnabled: isBannerLayoutAllowed)
          .frame(maxWidth: .infinity)
      }
      .navigationDestination(for: AppRoute.self) { route in
        switch route {
        case .countryDetail(let countryCode):
          if let definition = CountrySubdivisionRegistry.definition(for: countryCode) {
            SubdivisionCountryDetailView(definition: definition)
          } else {
            CountryDetailView(countryCode: countryCode)
          }
        case .japanMap:
          if appState.visitedCodes.contains("JP") {
            JapanMapScreen()
          } else if let definition = CountrySubdivisionRegistry.definition(for: "JP") {
            SubdivisionCountryDetailView(definition: definition)
          }
        case .franceMap:
          if appState.visitedCodes.contains("FR") {
            FranceMapScreen()
          } else if let definition = CountrySubdivisionRegistry.definition(for: "FR") {
            SubdivisionCountryDetailView(definition: definition)
          }
        case .subdivisionMap(let countryCode):
          if appState.visitedCodes.contains(countryCode),
            let definition = CountrySubdivisionRegistry.definition(for: countryCode)
          {
            SubdivisionMapScreen(definition: definition)
          } else if let definition = CountrySubdivisionRegistry.definition(for: countryCode) {
            SubdivisionCountryDetailView(definition: definition)
          }
        }
      }
    }
    .sheet(isPresented: $showingPicker) {
      CountryPickerView(initialSelection: appState.visitedCodes) { selection in
        Task {
          await appState.replaceVisitedCountries(with: selection)
        }
      }
    }
    .sheet(isPresented: $showingSettings) { SettingsView() }
  }

  private var header: some View {
    HStack(spacing: 0) {
      Text("Colorvia")
        .font(ColorviaTheme.logoFont(size: 34))
        .foregroundStyle(ColorviaTheme.ink)

      Spacer(minLength: 18)

      HStack(spacing: 12) {
        ShareLink(item: L10n.shareMessage(appState.visitedCountryCount)) {
          Image(systemName: "square.and.arrow.up")
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
        }
        .accessibilityLabel(L10n.text("common.share"))

        Button {
          showingSettings = true
        } label: {
          Image(systemName: "gearshape")
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
        }
        .accessibilityLabel(L10n.text("settings.title"))
      }
      .font(.system(size: 23, weight: .regular))
    }
    .foregroundStyle(ColorviaTheme.ink)
    .padding(.leading, 24)
    .padding(.trailing, 16)
    .padding(.top, 8)
  }

  private var addButton: some View {
    Button {
      showingPicker = true
    } label: {
      Image(systemName: "plus")
        .font(.system(size: 23, weight: .semibold))
        .foregroundStyle(.white)
        .frame(width: 58, height: 58)
        .background(ColorviaTheme.accentDeep, in: Circle())
        .overlay(Circle().stroke(.white.opacity(0.7), lineWidth: 1))
        .shadow(color: ColorviaTheme.ink.opacity(0.18), radius: 12, y: 6)
    }
    .accessibilityLabel(L10n.text("home.add_country"))
  }
}

private struct StatisticsBottomSheet: View {
  @Environment(AppState.self) private var appState
  @Binding var isExpanded: Bool
  let collapsedHeight: CGFloat
  let expandedHeight: CGFloat

  var body: some View {
    VStack(spacing: 0) {
      dragHandle

      summary
        .padding(.horizontal, 22)
        .contentShape(Rectangle())
        .gesture(dragGesture)

      if isExpanded {
        expandedStatistics
          .transition(.opacity.combined(with: .move(edge: .bottom)))
      } else {
        Text(continentSummary)
          .font(.subheadline)
          .foregroundStyle(ColorviaTheme.secondaryInk)
          .lineLimit(1)
          .padding(.top, 18)
          .transition(.opacity)
      }

      Spacer(minLength: 10)
    }
    .frame(maxWidth: .infinity)
    .frame(height: expandedHeight, alignment: .top)
    .background(
      ColorviaTheme.card,
      in: UnevenRoundedRectangle(topLeadingRadius: 36, topTrailingRadius: 36)
    )
    .shadow(color: ColorviaTheme.ink.opacity(0.09), radius: 22, y: -4)
    .offset(y: sheetOffset)
    .accessibilityAction(
      named: isExpanded ? L10n.text("stats.close") : L10n.text("stats.open")
    ) {
      withAnimation(.snappy(duration: 0.26)) {
        isExpanded.toggle()
      }
    }
  }

  private var dragHandle: some View {
    VStack {
      Capsule()
        .fill(ColorviaTheme.border.opacity(0.7))
        .frame(width: 42, height: 5)
    }
    .frame(maxWidth: .infinity)
    .frame(height: 25)
    .contentShape(Rectangle())
    .gesture(dragGesture)
    .accessibilityLabel(isExpanded ? L10n.text("stats.close") : L10n.text("stats.open"))
  }

  private var summary: some View {
    HStack(spacing: 0) {
      statistic(
        icon: "globe.asia.australia",
        value: "\(appState.visitedCountryCount)",
        suffix: L10n.countryUnit(appState.visitedCountryCount)
      )
      Divider().frame(height: 66)
      statistic(
        icon: "chart.pie",
        value: appState.worldPercentage.formatted(.number.precision(.fractionLength(1))),
        suffix: "%"
      )
    }
  }

  private var expandedStatistics: some View {
    VStack(spacing: 0) {
      Divider()
        .padding(.top, 18)

      HStack {
        Text(L10n.text("stats.title"))
          .font(.title3.weight(.semibold))
          .foregroundStyle(ColorviaTheme.ink)
        Spacer()
        Image(systemName: "chevron.down")
          .font(.caption.weight(.bold))
          .foregroundStyle(ColorviaTheme.secondaryInk)
      }
      .padding(.horizontal, 24)
      .padding(.top, 15)
      .padding(.bottom, 11)

      ScrollView {
        LazyVStack(spacing: 0) {
          Text(L10n.text("stats.by_continent"))
            .font(.caption.weight(.semibold))
            .foregroundStyle(ColorviaTheme.secondaryInk)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.bottom, 5)

          ForEach(Continent.allCases, id: \.self) { continent in
            HStack {
              Text(continent.localizedName)
              Spacer()
              Text(L10n.countryCount(appState.visitedCount(in: continent)))
                .foregroundStyle(ColorviaTheme.secondaryInk)
            }
            .font(.subheadline)
            .padding(.horizontal, 24)
            .padding(.vertical, 8)
          }

          Divider()
            .padding(.horizontal, 24)
            .padding(.vertical, 12)

          HStack {
            Text(L10n.text("stats.visited_countries"))
              .font(.headline)
            Spacer()
            Text(L10n.countryCount(visitedCountries.count))
              .font(.subheadline)
              .foregroundStyle(ColorviaTheme.secondaryInk)
          }
          .padding(.horizontal, 24)
          .padding(.bottom, 8)

          if visitedCountries.isEmpty {
            VStack(spacing: 8) {
              Image(systemName: "globe")
                .font(.title2)
              Text(L10n.text("stats.no_countries"))
                .font(.subheadline)
            }
            .foregroundStyle(ColorviaTheme.secondaryInk)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 30)
          } else {
            ForEach(visitedCountries) { country in
              NavigationLink(value: AppRoute.countryDetail(countryCode: country.id)) {
                HStack(spacing: 13) {
                  Text(country.flag)
                    .font(.title2)
                    .frame(width: 34)
                  VStack(alignment: .leading, spacing: 2) {
                    Text(country.localizedName)
                      .foregroundStyle(ColorviaTheme.ink)
                    if country.id == "JP" {
                      Text(
                        L10n.japanRowStatus(
                          isVisited: true,
                          prefectureCount: appState.visitedPrefectureCount
                        )
                      )
                      .font(.caption)
                      .foregroundStyle(ColorviaTheme.secondaryInk)
                    } else if country.id == "FR" {
                      Text(
                        L10n.franceRowStatus(
                          isVisited: true,
                          departmentCount: appState.visitedFranceDepartmentCount
                        )
                      )
                      .font(.caption)
                      .foregroundStyle(ColorviaTheme.secondaryInk)
                    } else if let definition = CountrySubdivisionRegistry.definition(
                      for: country.id
                    ) {
                      Text(
                        L10n.subdivisionRowStatus(
                          isVisited: true,
                          count: appState.visitedSubdivisionCount(countryCode: country.id),
                          total: definition.totalCount
                        )
                      )
                      .font(.caption)
                      .foregroundStyle(ColorviaTheme.secondaryInk)
                    }
                  }
                  Spacer()
                  Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ColorviaTheme.secondaryInk)
                }
                .contentShape(Rectangle())
              }
              .buttonStyle(.plain)
              .padding(.horizontal, 24)
              .padding(.vertical, 11)

              Divider().padding(.leading, 24)
            }
          }
        }
      }
      .scrollIndicators(.hidden)
    }
    .frame(maxHeight: .infinity)
  }

  private func statistic(icon: String, value: String, suffix: String) -> some View {
    VStack(spacing: 7) {
      Image(systemName: icon)
        .font(.title2)
        .frame(width: 43, height: 43)
        .background(ColorviaTheme.sea, in: Circle())
      HStack(alignment: .firstTextBaseline, spacing: 3) {
        Text(value).font(.system(size: 35, weight: .light, design: .serif))
        Text(suffix).font(.subheadline)
      }
    }
    .foregroundStyle(ColorviaTheme.ink)
    .frame(maxWidth: .infinity)
  }

  private var continentSummary: String {
    let entries = Continent.allCases
      .map { ($0, appState.visitedCount(in: $0)) }
      .filter { $0.1 > 0 }
      .prefix(2)
    if entries.isEmpty { return L10n.text("stats.swipe_up") }
    return entries.map { "\($0.0.localizedName) \($0.1)" }.joined(separator: "  /  ")
  }

  private var visitedCountries: [Country] {
    appState.countries
      .filter { appState.visitedCodes.contains($0.id) }
      .sorted {
        $0.localizedName.localizedStandardCompare($1.localizedName) == .orderedAscending
      }
  }

  private var sheetOffset: CGFloat {
    isExpanded ? 0 : expandedHeight - collapsedHeight
  }

  private var dragGesture: some Gesture {
    DragGesture(minimumDistance: 4)
      .onEnded { value in
        let projected = value.predictedEndTranslation.height
        withAnimation(.snappy(duration: 0.26)) {
          if isExpanded {
            isExpanded = projected < 90
          } else {
            isExpanded = projected < -70
          }
        }
      }
  }
}
