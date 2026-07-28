import SwiftUI

struct SubdivisionCountryDetailView: View {
  @Environment(AppState.self) private var appState
  @State private var confirmingRemoval = false
  let definition: CountrySubdivisionDefinition

  var body: some View {
    ScrollView {
      VStack(spacing: 24) {
        VStack(spacing: 9) {
          Text(flag).font(.system(size: 64))
          Text(definition.localizedCountryName)
            .font(.largeTitle.weight(.semibold))
          Text(isVisited ? L10n.text("filter.visited") : L10n.text("filter.unvisited"))
            .font(.headline)
            .foregroundStyle(isVisited ? ColorviaTheme.accentDeep : ColorviaTheme.secondaryInk)
        }

        if isVisited {
          progressCard
        } else {
          Text(L10n.text("subdivision.parent_required"))
            .font(.body)
            .foregroundStyle(ColorviaTheme.secondaryInk)
            .multilineTextAlignment(.center)
            .padding(20)
            .frame(maxWidth: .infinity)
            .background(ColorviaTheme.card, in: RoundedRectangle(cornerRadius: 24))
        }

        VStack(spacing: 12) {
          if isVisited {
            NavigationLink(
              value: AppRoute.subdivisionMap(countryCode: definition.countryCode)
            ) {
              Label(L10n.text("subdivision.open_map"), systemImage: "map")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .foregroundStyle(.white)
                .background(ColorviaTheme.accentDeep, in: Capsule())
            }
          }

          Button(role: isVisited ? .destructive : nil) {
            if isVisited {
              confirmingRemoval = true
            } else {
              Task { await appState.setVisited(true, countryCode: definition.countryCode) }
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
      }
      .padding(24)
    }
    .background(ColorviaTheme.background)
    .navigationTitle(definition.localizedCountryName)
    .navigationBarTitleDisplayMode(.inline)
    .confirmationDialog(
      L10n.removeCountryPrompt(definition.localizedCountryName),
      isPresented: $confirmingRemoval,
      titleVisibility: .visible
    ) {
      Button(L10n.text("subdivision.remove_all"), role: .destructive) {
        Task { await appState.setVisited(false, countryCode: definition.countryCode) }
      }
      Button(L10n.text("common.cancel"), role: .cancel) {}
    } message: {
      if visitedCount > 0 {
        Text(L10n.removeSubdivisionMessage(visitedCount))
      }
    }
    .tint(ColorviaTheme.accentDeep)
  }

  private var progressCard: some View {
    VStack(spacing: 15) {
      HStack(alignment: .firstTextBaseline) {
        Text("\(visitedCount) / \(definition.totalCount)")
          .font(.system(size: 34, weight: .light, design: .serif))
        Spacer()
        Text(percentage.formatted(.number.precision(.fractionLength(1))) + "%")
          .font(.headline)
          .foregroundStyle(ColorviaTheme.secondaryInk)
      }
      ProgressView(value: percentage, total: 100)
        .tint(appState.mapColor.color)
      Text(L10n.text("subdivision.progress"))
        .font(.subheadline)
        .foregroundStyle(ColorviaTheme.secondaryInk)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(20)
    .background(ColorviaTheme.card, in: RoundedRectangle(cornerRadius: 24))
  }

  private var flag: String {
    definition.countryCode.unicodeScalars.compactMap {
      UnicodeScalar(127397 + $0.value)
    }.map(String.init).joined()
  }

  private var isVisited: Bool {
    appState.visitedCodes.contains(definition.countryCode)
  }

  private var visitedCount: Int {
    appState.visitedSubdivisionCount(countryCode: definition.countryCode)
  }

  private var percentage: Double {
    appState.subdivisionPercentage(countryCode: definition.countryCode)
  }
}
