import SwiftUI

struct JapanMapScreen: View {
  @Environment(AppState.self) private var appState
  @State private var showingPicker = false
  @State private var isStatisticsExpanded = false

  var body: some View {
    GeometryReader { proxy in
      let collapsedHeight: CGFloat = 168
      let expandedHeight = min(proxy.size.height * 0.78, 660)

      ZStack(alignment: .bottomTrailing) {
        JapanMapView(
          prefectures: appState.mapPrefectures,
          visitedCodes: appState.visitedPrefectureCodes,
          visitedColor: appState.mapColor.color
        )
        .padding(.horizontal, 14)
        .padding(.top, 6)
        .padding(.bottom, collapsedHeight - 22)

        if !isStatisticsExpanded {
          addButton
            .padding(.trailing, 25)
            .padding(.bottom, collapsedHeight + 16)
            .transition(.scale(scale: 0.8).combined(with: .opacity))
        }

        JapanStatisticsBottomSheet(
          isExpanded: $isStatisticsExpanded,
          collapsedHeight: collapsedHeight,
          expandedHeight: expandedHeight
        )
        .environment(appState)
        .animation(.snappy(duration: 0.26), value: isStatisticsExpanded)
      }
    }
    .background(ColorviaTheme.background.ignoresSafeArea())
    .navigationTitle(japanName)
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ShareLink(item: L10n.japanShareMessage(appState.visitedPrefectureCount)) {
        Image(systemName: "square.and.arrow.up")
      }
    }
    .sheet(isPresented: $showingPicker) {
      PrefectureListView(initialSelection: appState.visitedPrefectureCodes) { selection in
        Task {
          await appState.replaceVisitedPrefectures(with: selection)
        }
      }
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
    .accessibilityLabel(L10n.text("prefecture_list.choose"))
  }

  private var japanName: String {
    Locale.current.localizedString(forRegionCode: "JP") ?? "Japan"
  }
}

private struct JapanStatisticsBottomSheet: View {
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
        Text(regionSummary)
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
        icon: "map",
        value: L10n.number(appState.visitedPrefectureCount),
        suffix: L10n.text("unit.prefectures")
      )
      Divider().frame(height: 66)
      statistic(
        icon: "chart.pie",
        value: appState.japanPercentage.formatted(.number.precision(.fractionLength(1))),
        suffix: "%"
      )
    }
  }

  private var expandedStatistics: some View {
    VStack(spacing: 0) {
      Divider()
        .padding(.top, 18)

      HStack {
        Text(L10n.text("japan_stats.title"))
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
          Text(L10n.text("japan_stats.by_region"))
            .font(.caption.weight(.semibold))
            .foregroundStyle(ColorviaTheme.secondaryInk)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.bottom, 5)

          ForEach(JapanRegion.allCases, id: \.self) { region in
            HStack {
              Text(region.localizedName)
              Spacer()
              Text(L10n.number(appState.visitedPrefectureCount(in: region)))
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
            Text(L10n.text("japan_stats.visited_prefectures"))
              .font(.headline)
            Spacer()
            Text(L10n.visitedPrefectureSummary(visitedPrefectures.count))
              .font(.subheadline)
              .foregroundStyle(ColorviaTheme.secondaryInk)
          }
          .padding(.horizontal, 24)
          .padding(.bottom, 8)

          if visitedPrefectures.isEmpty {
            VStack(spacing: 8) {
              Image(systemName: "map")
                .font(.title2)
              Text(L10n.text("japan_stats.no_prefectures"))
                .font(.subheadline)
            }
            .foregroundStyle(ColorviaTheme.secondaryInk)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 30)
          } else {
            ForEach(visitedPrefectures) { prefecture in
              HStack {
                Text(prefecture.localizedName)
                  .foregroundStyle(ColorviaTheme.ink)
                Spacer()
              }
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

  private var regionSummary: String {
    let entries = JapanRegion.allCases
      .map { ($0, appState.visitedPrefectureCount(in: $0)) }
      .filter { $0.1 > 0 }
      .prefix(2)
    if entries.isEmpty { return L10n.text("japan_stats.swipe_up") }
    return entries.map { "\($0.0.localizedName) \($0.1)" }.joined(separator: "  /  ")
  }

  private var visitedPrefectures: [Prefecture] {
    appState.prefectures.filter { appState.visitedPrefectureCodes.contains($0.id) }
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
