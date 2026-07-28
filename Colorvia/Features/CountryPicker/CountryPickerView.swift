import SwiftUI

struct CountryPickerView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(AppState.self) private var appState
  @State private var selection: Set<String>
  @State private var searchText = ""
  let onComplete: (Set<String>) -> Void

  init(initialSelection: Set<String>, onComplete: @escaping (Set<String>) -> Void) {
    _selection = State(initialValue: initialSelection)
    self.onComplete = onComplete
  }

  var body: some View {
    NavigationStack {
      List {
        mapPreview
          .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 12, trailing: 16))
          .listRowBackground(Color.clear)

        ForEach(Continent.allCases, id: \.self) { continent in
          let countries = filteredCountries.filter { $0.continent == continent }
          if !countries.isEmpty {
            Section(continent.localizedName) {
              ForEach(countries) { country in
                Button {
                  toggle(country.id)
                } label: {
                  HStack(spacing: 12) {
                    Text(country.flag).font(.title2)
                    VStack(alignment: .leading, spacing: 2) {
                      Text(country.localizedName).foregroundStyle(ColorviaTheme.ink)
                      Text(country.englishName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(
                      systemName: selection.contains(country.id)
                        ? "checkmark.circle.fill" : "circle"
                    )
                    .foregroundStyle(
                      selection.contains(country.id) ? ColorviaTheme.accent : .secondary)
                  }
                }
              }
            }
          }
        }
      }
      .listStyle(.insetGrouped)
      .scrollContentBackground(.hidden)
      .background(ColorviaTheme.background)
      .navigationTitle(L10n.text("picker.title"))
      .navigationBarTitleDisplayMode(.inline)
      .searchable(text: $searchText, prompt: L10n.text("picker.search"))
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(L10n.text("common.cancel")) { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button(L10n.selectedCount(selection.count)) {
            onComplete(selection)
            dismiss()
          }
          .fontWeight(.semibold)
        }
      }
    }
    .presentationDetents([.large])
    .tint(ColorviaTheme.accentDeep)
  }

  private var mapPreview: some View {
    WorldMapView(
      countries: appState.mapCountries,
      visitedCodes: selection,
      compact: true,
      visitedColor: appState.mapColor.color
    )
    .frame(height: 155)
    .accessibilityHidden(true)
  }

  private var filteredCountries: [Country] {
    let base = appState.countries.sorted {
      $0.localizedName.localizedStandardCompare($1.localizedName) == .orderedAscending
    }
    guard !searchText.isEmpty else { return base }
    let query =
      searchText
      .folding(
        options: [.caseInsensitive, .widthInsensitive, .diacriticInsensitive], locale: .current
      )
      .lowercased()
    return base.filter { $0.searchableText.contains(query) }
  }

  private func toggle(_ code: String) {
    if selection.contains(code) {
      selection.remove(code)
    } else {
      selection.insert(code)
      UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }
  }
}
