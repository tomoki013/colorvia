import SwiftUI

struct SubdivisionListView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(AppState.self) private var appState
  @State private var selection: Set<String>
  @State private var searchText = ""
  @State private var filter: SubdivisionVisitFilter = .all
  @State private var aliases: [PlaceSearchAlias] = []
  @State private var searchResults: [String: PlaceSearchAlias] = [:]
  @State private var isLoadingSearch = true
  let definition: CountrySubdivisionDefinition
  let onComplete: (Set<String>) -> Void

  init(
    definition: CountrySubdivisionDefinition,
    initialSelection: Set<String>,
    onComplete: @escaping (Set<String>) -> Void
  ) {
    self.definition = definition
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

        ForEach(groups, id: \.code) { group in
          let rows = filteredSubdivisions.filter { $0.groupCode == group.code }
          if !rows.isEmpty {
            Section(group.name) {
              ForEach(rows) { subdivision in
                row(subdivision)
              }
            }
          }
        }
      }
      .listStyle(.insetGrouped)
      .scrollContentBackground(.hidden)
      .background(ColorviaTheme.background)
      .navigationTitle(L10n.text("subdivision.choose"))
      .navigationBarTitleDisplayMode(.inline)
      .searchable(text: $searchText, prompt: L10n.text("subdivision.search"))
      .onChange(of: searchText) { _, query in
        updateSearch(query)
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
          .accessibilityLabel(L10n.selectedSubdivisionCount(selection.count))
        }
      }
    }
    .presentationDetents([.medium, .large])
    .presentationDragIndicator(.visible)
    .presentationContentInteraction(.scrolls)
    .tint(ColorviaTheme.accentDeep)
    .task {
      do {
        aliases = try await PlaceSearchIndexStore.load(
          resourceName: definition.searchIndexResourceName
        )
        if !searchText.isEmpty {
          updateSearch(searchText)
        }
      } catch {
        appState.lastError = error.localizedDescription
      }
      isLoadingSearch = false
    }
  }

  private func row(_ subdivision: AdministrativeSubdivision) -> some View {
    Button {
      if selection.contains(subdivision.id) {
        selection.remove(subdivision.id)
      } else {
        selection.insert(subdivision.id)
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
      }
    } label: {
      HStack {
        VStack(alignment: .leading, spacing: 3) {
          Text(subdivision.localizedName)
            .foregroundStyle(ColorviaTheme.ink)
          Text(subdivision.code)
            .font(.caption)
            .foregroundStyle(ColorviaTheme.secondaryInk)
          if searchResults[subdivision.id] != nil {
            Text(L10n.placeMatchReason(searchText))
              .font(.caption)
              .foregroundStyle(ColorviaTheme.secondaryInk)
          }
        }
        Spacer()
        Image(
          systemName: selection.contains(subdivision.id)
            ? "checkmark.circle.fill" : "circle"
        )
        .foregroundStyle(selection.contains(subdivision.id) ? ColorviaTheme.accent : .secondary)
      }
    }
    .buttonStyle(.plain)
  }

  private var mapPreview: some View {
    JapanMapView(
      prefectures: appState.subdivisionGeometryByCountry[definition.countryCode, default: []],
      visitedCodes: selection,
      compact: true,
      visitedColor: appState.mapColor.color,
      accessibilityLabel: L10n.text("subdivision.map_accessibility")
    )
    .frame(height: 210)
    .accessibilityHidden(true)
  }

  private var filterControls: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        Text(L10n.selectedSubdivisionCount(selection.count))
          .font(.subheadline.weight(.semibold))
        Spacer()
        if isLoadingSearch { ProgressView().controlSize(.small) }
      }
      .foregroundStyle(ColorviaTheme.secondaryInk)
      Picker(L10n.text("filter.title"), selection: $filter) {
        ForEach(SubdivisionVisitFilter.allCases, id: \.self) {
          Text($0.localizedName).tag($0)
        }
      }
      .pickerStyle(.segmented)
    }
  }

  private var filteredSubdivisions: [AdministrativeSubdivision] {
    subdivisions.filter { subdivision in
      let filterMatches =
        switch filter {
        case .all: true
        case .visited: selection.contains(subdivision.id)
        case .unvisited: !selection.contains(subdivision.id)
        }
      return filterMatches && (searchText.isEmpty || searchResults[subdivision.id] != nil)
    }
  }

  private var subdivisions: [AdministrativeSubdivision] {
    appState.subdivisionsByCountry[definition.countryCode, default: []]
  }

  private var groups: [(code: String, name: String)] {
    var seen: Set<String> = []
    return subdivisions.compactMap {
      let code = $0.groupCode
      guard seen.insert(code).inserted else { return nil }
      return (code, $0.groupCode.isEmpty ? L10n.text("subdivision.regions") : $0.localizedGroupName)
    }
  }

  private func updateSearch(_ query: String) {
    let source = aliases
    Task {
      let results = await Task.detached {
        PlaceSearchService.bestMatches(query: query, aliases: source)
      }.value
      guard query == searchText else { return }
      searchResults = results
    }
  }
}

private enum SubdivisionVisitFilter: CaseIterable {
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
