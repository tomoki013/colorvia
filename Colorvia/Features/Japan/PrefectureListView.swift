import SwiftUI

struct PrefectureListView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(AppState.self) private var appState
  @State private var selection: Set<String>
  @State private var searchText = ""
  @State private var filter: VisitFilter = .all
  @State private var highlightedCode: String?
  @State private var searchResults: [String: PlaceSearchAlias] = [:]
  let onComplete: (Set<String>) -> Void

  init(
    initialSelection: Set<String>,
    onComplete: @escaping (Set<String>) -> Void
  ) {
    _selection = State(initialValue: initialSelection)
    self.onComplete = onComplete
  }

  var body: some View {
    NavigationStack {
      List {
        mapPreview
          .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 12, trailing: 16))
          .listRowBackground(Color.clear)

        filterControls
          .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: 10, trailing: 16))
          .listRowBackground(Color.clear)

        ForEach(JapanRegion.allCases, id: \.self) { region in
          let prefectures = filteredPrefectures.filter { $0.region == region }
          if !prefectures.isEmpty {
            Section(region.localizedName) {
              ForEach(prefectures) { prefecture in
                Button {
                  toggle(prefecture)
                } label: {
                  HStack {
                    VStack(alignment: .leading, spacing: 3) {
                      Text(prefecture.localizedName)
                        .foregroundStyle(ColorviaTheme.ink)
                      if let match = searchResults[prefecture.id] {
                        Text(L10n.placeMatchReason(match.localizedDisplayName))
                          .font(.caption)
                          .foregroundStyle(ColorviaTheme.secondaryInk)
                      }
                    }
                    Spacer()
                    Image(
                      systemName: selection.contains(prefecture.id)
                        ? "checkmark.circle.fill" : "circle"
                    )
                    .foregroundStyle(
                      selection.contains(prefecture.id)
                        ? ColorviaTheme.accent : .secondary
                    )
                  }
                }
                .buttonStyle(.plain)
              }
            }
          }
        }
      }
      .listStyle(.insetGrouped)
      .scrollContentBackground(.hidden)
      .background(ColorviaTheme.background)
      .navigationTitle(L10n.text("prefecture_list.title"))
      .navigationBarTitleDisplayMode(.inline)
      .searchable(text: $searchText, prompt: L10n.text("prefecture_list.search"))
      .onChange(of: searchText) { _, query in
        searchResults = PlaceSearchService.bestMatches(
          query: query,
          aliases: appState.japanPlaceAliases
        )
      }
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button {
            dismiss()
          } label: {
            Image(systemName: "xmark")
          }
          .accessibilityLabel(L10n.text("common.cancel"))
        }
        ToolbarItem(placement: .confirmationAction) {
          Button {
            onComplete(selection)
            dismiss()
          } label: {
            Image(systemName: "checkmark")
          }
          .accessibilityLabel(L10n.selectedPrefectureCount(selection.count))
        }
      }
    }
    .presentationDetents([.medium, .large])
    .presentationDragIndicator(.visible)
    .presentationContentInteraction(.scrolls)
    .tint(ColorviaTheme.accentDeep)
  }

  private var mapPreview: some View {
    JapanMapView(
      prefectures: appState.mapPrefectures,
      visitedCodes: selection,
      compact: true,
      visitedColor: appState.mapColor.color,
      highlightedCode: highlightedCode
    )
    .frame(height: 210)
    .accessibilityHidden(true)
  }

  private var filterControls: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(L10n.visitedPrefectureSummary(selection.count))
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(ColorviaTheme.secondaryInk)
      Picker(L10n.text("filter.title"), selection: $filter) {
        ForEach(VisitFilter.allCases, id: \.self) { filter in
          Text(filter.localizedName).tag(filter)
        }
      }
      .pickerStyle(.segmented)
    }
  }

  private var filteredPrefectures: [Prefecture] {
    appState.prefectures.filter { prefecture in
      let matchesFilter =
        switch filter {
        case .all: true
        case .visited: selection.contains(prefecture.id)
        case .unvisited: !selection.contains(prefecture.id)
        }
      guard matchesFilter else { return false }
      guard !searchText.isEmpty else { return true }
      return searchResults[prefecture.id] != nil
    }
  }

  private func toggle(_ prefecture: Prefecture) {
    highlightedCode = prefecture.id
    if selection.contains(prefecture.id) {
      selection.remove(prefecture.id)
    } else {
      selection.insert(prefecture.id)
      UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }
    Task {
      try? await Task.sleep(for: .milliseconds(650))
      if highlightedCode == prefecture.id {
        highlightedCode = nil
      }
    }
  }
}

private enum VisitFilter: CaseIterable {
  case all
  case visited
  case unvisited

  var localizedName: String {
    switch self {
    case .all: L10n.text("filter.all")
    case .visited: L10n.text("filter.visited")
    case .unvisited: L10n.text("filter.unvisited")
    }
  }
}
