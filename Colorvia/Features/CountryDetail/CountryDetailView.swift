import SwiftUI

struct CountryDetailView: View {
  @Environment(AppState.self) private var appState
  @State private var confirmingRemoval = false
  let countryCode: String

  var body: some View {
    Group {
      if let country {
        ScrollView {
          VStack(spacing: 24) {
            VStack(spacing: 10) {
              Text(country.flag)
                .font(.system(size: 72))
              Text(country.localizedName)
                .font(.largeTitle.weight(.semibold))
                .foregroundStyle(ColorviaTheme.ink)
              if country.localizedName != country.englishName {
                Text(country.englishName)
                  .font(.subheadline)
                  .foregroundStyle(ColorviaTheme.secondaryInk)
              }
            }

            detailCard(country)

            Button(role: isVisited ? .destructive : nil) {
              if isVisited {
                confirmingRemoval = true
              } else {
                Task { await appState.setVisited(true, countryCode: country.id) }
              }
            } label: {
              Text(
                isVisited
                  ? L10n.text("country_list.remove_visited")
                  : L10n.text("japan_detail.mark_visited")
              )
              .font(.headline)
              .frame(maxWidth: .infinity)
              .padding(.vertical, 15)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
          }
          .padding(24)
        }
        .navigationTitle(country.localizedName)
        .confirmationDialog(
          L10n.removeCountryPrompt(country.localizedName),
          isPresented: $confirmingRemoval,
          titleVisibility: .visible
        ) {
          Button(L10n.text("country_list.remove_visited"), role: .destructive) {
            Task { await appState.setVisited(false, countryCode: country.id) }
          }
          Button(L10n.text("common.cancel"), role: .cancel) {}
        }
      }
    }
    .background(ColorviaTheme.background)
    .navigationBarTitleDisplayMode(.inline)
    .tint(ColorviaTheme.accentDeep)
  }

  private func detailCard(_ country: Country) -> some View {
    VStack(spacing: 0) {
      detailRow(
        title: L10n.text("country_detail.status"),
        value: isVisited ? L10n.text("filter.visited") : L10n.text("filter.unvisited")
      )
      Divider()
      detailRow(
        title: L10n.text("country_detail.continent"),
        value: country.continent.localizedName
      )
      Divider()
      detailRow(
        title: L10n.text("country_detail.code"),
        value: "\(country.alpha2Code) / \(country.alpha3Code)"
      )
    }
    .padding(.horizontal, 18)
    .background(ColorviaTheme.card, in: RoundedRectangle(cornerRadius: 24))
  }

  private func detailRow(title: String, value: String) -> some View {
    HStack {
      Text(title)
        .foregroundStyle(ColorviaTheme.secondaryInk)
      Spacer()
      Text(value)
        .foregroundStyle(ColorviaTheme.ink)
    }
    .padding(.vertical, 16)
  }

  private var country: Country? {
    appState.countries.first { $0.id == countryCode }
  }

  private var isVisited: Bool {
    appState.visitedCodes.contains(countryCode)
  }
}
