import SwiftUI

struct SubdivisionMapScreen: View {
  @Environment(AppState.self) private var appState
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var showingPicker = false
  @State private var showingShareSheet = false
  @State private var isStatisticsExpanded = false
  let definition: CountrySubdivisionDefinition

  var body: some View {
    GeometryReader { proxy in
      let collapsedHeight: CGFloat = 168
      let expandedHeight = min(proxy.size.height * 0.78, 660)
      ZStack(alignment: .bottomTrailing) {
        JapanMapView(
          prefectures: geometry,
          visitedCodes: visitedCodes,
          visitedColor: appState.mapColor.color,
          accessibilityLabel: L10n.text("subdivision.map_accessibility")
        )
        .padding(.horizontal, 14)
        .padding(.top, 6)
        .padding(.bottom, collapsedHeight - 22)

        if !isStatisticsExpanded {
          addButton
            .padding(.trailing, 25)
            .padding(.bottom, collapsedHeight + 16)
        }

        SubdivisionStatisticsCard(
          definition: definition,
          isExpanded: $isStatisticsExpanded,
          collapsedHeight: collapsedHeight,
          expandedHeight: expandedHeight
        )
        .environment(appState)
        .animation(reduceMotion ? nil : .snappy(duration: 0.26), value: isStatisticsExpanded)
      }
    }
    .background(ColorviaTheme.background.ignoresSafeArea())
    .navigationTitle(definition.localizedCountryName)
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      Button {
        showingShareSheet = true
      } label: {
        Image(systemName: "square.and.arrow.up")
      }
      .accessibilityLabel(L10n.text("common.share"))
    }
    .sheet(isPresented: $showingPicker) {
      SubdivisionListView(
        definition: definition,
        initialSelection: visitedCodes
      ) { selection in
        Task {
          await appState.replaceVisitedSubdivisions(
            countryCode: definition.countryCode,
            with: selection
          )
        }
      }
    }
    .sheet(isPresented: $showingShareSheet) {
      SubdivisionShareSheet(
        definition: definition,
        geometry: geometry,
        visitedCodes: visitedCodes,
        visitedColor: appState.mapColor.color
      )
    }
    .tint(ColorviaTheme.accentDeep)
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
    .accessibilityLabel(L10n.text("subdivision.choose"))
  }

  private var geometry: [MapPrefecture] {
    appState.subdivisionGeometryByCountry[definition.countryCode, default: []]
  }

  private var visitedCodes: Set<String> {
    appState.visitedSubdivisionCodes(countryCode: definition.countryCode)
  }

}

private struct SubdivisionStatisticsCard: View {
  @Environment(AppState.self) private var appState
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  let definition: CountrySubdivisionDefinition
  @Binding var isExpanded: Bool
  let collapsedHeight: CGFloat
  let expandedHeight: CGFloat

  var body: some View {
    VStack(spacing: 0) {
      Capsule()
        .fill(ColorviaTheme.border.opacity(0.7))
        .frame(width: 42, height: 5)
        .frame(maxWidth: .infinity)
        .frame(height: 25)
        .contentShape(Rectangle())
        .gesture(dragGesture)

      HStack {
        statistic(
          icon: "map",
          value: "\(appState.visitedSubdivisionCount(countryCode: definition.countryCode))",
          suffix: L10n.text("unit.regions")
        )
        Divider().frame(height: 66)
        statistic(
          icon: "chart.pie",
          value: appState.subdivisionPercentage(countryCode: definition.countryCode)
            .formatted(.number.precision(.fractionLength(1))),
          suffix: "%"
        )
      }
      .padding(.horizontal, 22)
      .contentShape(Rectangle())
      .gesture(dragGesture)

      if isExpanded {
        Divider().padding(.top, 18)
        ScrollView {
          LazyVStack(spacing: 0) {
            ForEach(visitedSubdivisions) { subdivision in
              HStack {
                Text(subdivision.localizedName)
                Spacer()
                Text(subdivision.code).foregroundStyle(ColorviaTheme.secondaryInk)
              }
              .padding(.horizontal, 24)
              .padding(.vertical, 10)
            }
          }
        }
        .scrollIndicators(.hidden)
      } else {
        Text(L10n.text("stats.swipe_up"))
          .font(.subheadline)
          .foregroundStyle(ColorviaTheme.secondaryInk)
          .padding(.top, 18)
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
    .offset(y: isExpanded ? 0 : expandedHeight - collapsedHeight)
    .accessibilityAction(
      named: isExpanded ? L10n.text("stats.close") : L10n.text("stats.open")
    ) {
      if reduceMotion {
        isExpanded.toggle()
      } else {
        withAnimation(.snappy(duration: 0.26)) { isExpanded.toggle() }
      }
    }
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
    .frame(maxWidth: .infinity)
  }

  private var visitedSubdivisions: [AdministrativeSubdivision] {
    let codes = appState.visitedSubdivisionCodes(countryCode: definition.countryCode)
    return appState.subdivisionsByCountry[definition.countryCode, default: []].filter {
      codes.contains($0.id)
    }
  }

  private var dragGesture: some Gesture {
    DragGesture(minimumDistance: 4)
      .onEnded { value in
        let projected = value.predictedEndTranslation.height
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.26)) {
          isExpanded = isExpanded ? projected < 90 : projected < -70
        }
      }
  }
}
