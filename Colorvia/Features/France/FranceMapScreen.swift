import SwiftUI

struct FranceMapScreen: View {
  @Environment(AppState.self) private var appState
  @State private var showingPicker = false
  @State private var showingShareSheet = false
  @State private var isStatisticsExpanded = false

  var body: some View {
    GeometryReader { proxy in
      let collapsedHeight: CGFloat = 168
      let expandedHeight = min(proxy.size.height * 0.78, 660)

      ZStack(alignment: .bottomTrailing) {
        franceMap
          .padding(.horizontal, 14)
          .padding(.top, 6)
          .padding(.bottom, collapsedHeight - 22)

        if !isStatisticsExpanded {
          addButton
            .padding(.trailing, 25)
            .padding(.bottom, collapsedHeight + 16)
            .transition(.scale(scale: 0.8).combined(with: .opacity))
        }

        FranceStatisticsBottomSheet(
          isExpanded: $isStatisticsExpanded,
          collapsedHeight: collapsedHeight,
          expandedHeight: expandedHeight
        )
        .environment(appState)
        .animation(.snappy(duration: 0.26), value: isStatisticsExpanded)
      }
    }
    .background(ColorviaTheme.background.ignoresSafeArea())
    .navigationTitle(franceName)
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
      FranceDepartmentListView(initialSelection: appState.visitedFranceDepartmentCodes) {
        selection in
        Task {
          await appState.replaceVisitedFranceDepartments(with: selection)
        }
      }
    }
    .sheet(isPresented: $showingShareSheet) {
      FranceShareSheet(
        departments: appState.mapFranceDepartments,
        visitedCodes: appState.visitedFranceDepartmentCodes,
        visitedColor: appState.mapColor.color
      )
    }
    .tint(ColorviaTheme.accentDeep)
  }

  private var franceMap: some View {
    ZStack(alignment: .bottom) {
      JapanMapView(
        prefectures: appState.mapFranceDepartments,
        visitedCodes: appState.visitedFranceDepartmentCodes,
        visitedColor: appState.mapColor.color,
        accessibilityLabel: L10n.text("france_map.accessibility_label")
      )
      HStack(spacing: 5) {
        ForEach(["Guadeloupe", "Martinique", "Guyane", "La Réunion", "Mayotte"], id: \.self) {
          name in
          Text(name)
            .font(.system(size: 7, weight: .medium))
            .lineLimit(1)
            .minimumScaleFactor(0.55)
            .frame(maxWidth: .infinity)
        }
      }
      .foregroundStyle(ColorviaTheme.secondaryInk)
      .padding(.horizontal, 10)
      .padding(.bottom, 8)
    }
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
    .accessibilityLabel(L10n.text("france_list.choose"))
  }

  private var franceName: String {
    Locale.current.localizedString(forRegionCode: "FR") ?? "France"
  }
}

private struct FranceStatisticsBottomSheet: View {
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
        Text(groupSummary)
          .font(.subheadline)
          .foregroundStyle(ColorviaTheme.secondaryInk)
          .lineLimit(1)
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
  }

  private var dragHandle: some View {
    Capsule()
      .fill(ColorviaTheme.border.opacity(0.7))
      .frame(width: 42, height: 5)
      .frame(maxWidth: .infinity)
      .frame(height: 25)
      .contentShape(Rectangle())
      .gesture(dragGesture)
  }

  private var summary: some View {
    HStack(spacing: 0) {
      statistic(
        icon: "map",
        value: L10n.number(appState.visitedFranceDepartmentCount),
        suffix: L10n.text("unit.regions")
      )
      Divider().frame(height: 66)
      statistic(
        icon: "chart.pie",
        value: appState.francePercentage.formatted(.number.precision(.fractionLength(1))),
        suffix: "%"
      )
    }
  }

  private var expandedStatistics: some View {
    VStack(spacing: 0) {
      Divider().padding(.top, 18)
      HStack {
        Text(L10n.text("france_stats.title"))
          .font(.title3.weight(.semibold))
        Spacer()
        Image(systemName: "chevron.down")
          .font(.caption.weight(.bold))
          .foregroundStyle(ColorviaTheme.secondaryInk)
      }
      .padding(.horizontal, 24)
      .padding(.vertical, 13)

      ScrollView {
        LazyVStack(spacing: 0) {
          ForEach(groups, id: \.code) { group in
            HStack {
              Text(group.name)
              Spacer()
              Text(L10n.number(appState.visitedFranceDepartmentCount(in: group.code)))
                .foregroundStyle(ColorviaTheme.secondaryInk)
            }
            .font(.subheadline)
            .padding(.horizontal, 24)
            .padding(.vertical, 8)
          }
          Divider().padding(.horizontal, 24).padding(.vertical, 12)
          ForEach(visitedDepartments) { department in
            HStack {
              Text(department.localizedName)
              Spacer()
              Text(department.code)
                .foregroundStyle(ColorviaTheme.secondaryInk)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
          }
        }
      }
      .scrollIndicators(.hidden)
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

  private var groups: [(code: String, name: String)] {
    var seen: Set<String> = []
    return appState.franceDepartments.compactMap { department in
      guard seen.insert(department.groupCode).inserted else { return nil }
      return (department.groupCode, department.groupName)
    }
  }

  private var visitedDepartments: [FranceDepartment] {
    appState.franceDepartments.filter {
      appState.visitedFranceDepartmentCodes.contains($0.id)
    }
  }

  private var groupSummary: String {
    let entries =
      groups
      .map { ($0.name, appState.visitedFranceDepartmentCount(in: $0.code)) }
      .filter { $0.1 > 0 }
      .prefix(2)
    if entries.isEmpty { return L10n.text("stats.swipe_up") }
    return entries.map { "\($0.0) \($0.1)" }.joined(separator: "  /  ")
  }

  private var dragGesture: some Gesture {
    DragGesture(minimumDistance: 4)
      .onEnded { value in
        let projected = value.predictedEndTranslation.height
        withAnimation(.snappy(duration: 0.26)) {
          isExpanded = isExpanded ? projected < 90 : projected < -70
        }
      }
  }
}
