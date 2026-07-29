import SwiftUI

struct FranceDepartmentListView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(AppState.self) private var appState
  @State private var selection: Set<String>
  @State private var searchText = ""
  @State private var filter: DepartmentVisitFilter = .all
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

        ForEach(groups, id: \.code) { group in
          let departments = filteredDepartments.filter { $0.groupCode == group.code }
          if !departments.isEmpty {
            Section(group.name) {
              ForEach(departments) { department in
                Button {
                  toggle(department)
                } label: {
                  HStack {
                    VStack(alignment: .leading, spacing: 3) {
                      Text(department.localizedName)
                        .foregroundStyle(ColorviaTheme.ink)
                      Text(department.code)
                        .font(.caption)
                        .foregroundStyle(ColorviaTheme.secondaryInk)
                      if let match = searchResults[department.id] {
                        Text(L10n.placeMatchReason(match.localizedDisplayName))
                          .font(.caption)
                          .foregroundStyle(ColorviaTheme.secondaryInk)
                      }
                    }
                    Spacer()
                    Image(
                      systemName: selection.contains(department.id)
                        ? "checkmark.circle.fill" : "circle"
                    )
                    .foregroundStyle(
                      selection.contains(department.id)
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
      .navigationTitle(L10n.text("france_list.title"))
      .navigationBarTitleDisplayMode(.inline)
      .searchable(text: $searchText, prompt: L10n.text("france_list.search"))
      .onChange(of: searchText) { _, query in
        let aliases = appState.francePlaceAliases
        Task {
          let results = await Task.detached {
            PlaceSearchService.bestMatches(query: query, aliases: aliases)
          }.value
          guard query == searchText else { return }
          searchResults = results
        }
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
          .accessibilityLabel(L10n.selectedDepartmentCount(selection.count))
        }
      }
    }
    .presentationDetents([.large])
    .presentationDragIndicator(.visible)
    .presentationContentInteraction(.scrolls)
    .tint(ColorviaTheme.accentDeep)
  }

  private var mapPreview: some View {
    JapanMapView(
      prefectures: appState.mapFranceDepartments,
      visitedCodes: selection,
      compact: true,
      visitedColor: appState.mapColor.color,
      highlightedCode: highlightedCode,
      accessibilityLabel: L10n.text("france_map.accessibility_label")
    )
    .frame(height: 210)
    .accessibilityHidden(true)
  }

  private var filterControls: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(L10n.visitedDepartmentSummary(selection.count))
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(ColorviaTheme.secondaryInk)
      Picker(L10n.text("filter.title"), selection: $filter) {
        ForEach(DepartmentVisitFilter.allCases, id: \.self) { filter in
          Text(filter.localizedName).tag(filter)
        }
      }
      .pickerStyle(.segmented)
    }
  }

  private var filteredDepartments: [FranceDepartment] {
    appState.franceDepartments.filter { department in
      let matchesFilter =
        switch filter {
        case .all: true
        case .visited: selection.contains(department.id)
        case .unvisited: !selection.contains(department.id)
        }
      guard matchesFilter else { return false }
      guard !searchText.isEmpty else { return true }
      return searchResults[department.id] != nil
    }
  }

  private var groups: [(code: String, name: String)] {
    var seen: Set<String> = []
    return appState.franceDepartments.compactMap { department in
      guard seen.insert(department.groupCode).inserted else { return nil }
      return (department.groupCode, department.groupName)
    }
  }

  private func toggle(_ department: FranceDepartment) {
    highlightedCode = department.id
    if selection.contains(department.id) {
      selection.remove(department.id)
    } else {
      selection.insert(department.id)
      UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }
    Task {
      try? await Task.sleep(for: .milliseconds(650))
      if highlightedCode == department.id {
        highlightedCode = nil
      }
    }
  }
}

private enum DepartmentVisitFilter: CaseIterable {
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
