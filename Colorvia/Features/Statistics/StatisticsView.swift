import SwiftUI

struct StatisticsView: View {
  @Environment(AppState.self) private var appState
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 24) {
          HStack(spacing: 14) {
            hero(
              value: "\(appState.visitedCountryCount)",
              label: L10n.text("stats.visited_countries"))
            hero(
              value:
                "\(appState.worldPercentage.formatted(.number.precision(.fractionLength(1))))%",
              label: L10n.text("stats.world_percentage"))
          }

          VStack(spacing: 0) {
            ForEach(Continent.allCases, id: \.self) { continent in
              HStack {
                Text(continent.localizedName)
                Spacer()
                Text(L10n.countryCount(appState.visitedCount(in: continent)))
                  .foregroundStyle(ColorviaTheme.secondaryInk)
              }
              .padding(.vertical, 15)
              if continent != Continent.allCases.last { Divider() }
            }
          }
          .padding(.horizontal, 18)
          .background(ColorviaTheme.card, in: RoundedRectangle(cornerRadius: 22))
        }
        .padding(20)
      }
      .background(ColorviaTheme.background)
      .navigationTitle(L10n.text("stats.title"))
      .navigationBarTitleDisplayMode(.inline)
      .toolbar { Button(L10n.text("common.close")) { dismiss() } }
    }
    .tint(ColorviaTheme.accentDeep)
  }

  private func hero(value: String, label: String) -> some View {
    VStack(spacing: 8) {
      Text(value)
        .font(.system(size: 36, weight: .light, design: .serif))
        .foregroundStyle(ColorviaTheme.ink)
      Text(label).font(.caption).foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 24)
    .background(ColorviaTheme.card, in: RoundedRectangle(cornerRadius: 22))
  }
}
