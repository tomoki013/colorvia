import SwiftUI

struct JapanDetailView: View {
  @Environment(AppState.self) private var appState
  @State private var confirmingRemoval = false

  var body: some View {
    ScrollView {
      VStack(spacing: 24) {
        VStack(spacing: 9) {
          Text(L10n.text("japan.flag"))
            .font(.system(size: 64))
          Text(japanName)
            .font(.largeTitle.weight(.semibold))
            .foregroundStyle(ColorviaTheme.ink)
          Text(isVisited ? L10n.text("filter.visited") : L10n.text("filter.unvisited"))
            .font(.headline)
            .foregroundStyle(isVisited ? ColorviaTheme.accentDeep : ColorviaTheme.secondaryInk)
        }

        progressCard

        VStack(spacing: 12) {
          NavigationLink(value: AppRoute.japanMap) {
            Label(L10n.text("japan_detail.open_map"), systemImage: "map")
              .font(.headline)
              .frame(maxWidth: .infinity)
              .padding(.vertical, 16)
              .foregroundStyle(.white)
              .background(ColorviaTheme.accentDeep, in: Capsule())
          }

          Button(role: isVisited ? .destructive : nil) {
            if isVisited {
              confirmingRemoval = true
            } else {
              Task { await appState.setVisited(true, countryCode: "JP") }
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
    .navigationTitle(japanName)
    .navigationBarTitleDisplayMode(.inline)
    .confirmationDialog(
      removalPrompt,
      isPresented: $confirmingRemoval,
      titleVisibility: .visible
    ) {
      Button(removalButtonTitle, role: .destructive) {
        Task { await appState.setVisited(false, countryCode: "JP") }
      }
      Button(L10n.text("common.cancel"), role: .cancel) {}
    } message: {
      if appState.visitedPrefectureCount > 0 {
        Text(L10n.removeJapanMessage(appState.visitedPrefectureCount))
      }
    }
    .tint(ColorviaTheme.accentDeep)
  }

  private var progressCard: some View {
    VStack(spacing: 15) {
      HStack(alignment: .firstTextBaseline) {
        Text(L10n.prefectureFraction(appState.visitedPrefectureCount))
          .font(.system(size: 34, weight: .light, design: .serif))
        Spacer()
        Text(
          L10n.percentage(
            appState.japanPercentage.formatted(.number.precision(.fractionLength(1)))
          )
        )
        .font(.headline)
        .foregroundStyle(ColorviaTheme.secondaryInk)
      }
      ProgressView(value: appState.japanPercentage, total: 100)
        .tint(appState.mapColor.color)
      Text(L10n.text("japan_detail.prefecture_progress"))
        .font(.subheadline)
        .foregroundStyle(ColorviaTheme.secondaryInk)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(20)
    .background(ColorviaTheme.card, in: RoundedRectangle(cornerRadius: 24))
  }

  private var japanName: String {
    Locale.current.localizedString(forRegionCode: "JP") ?? "Japan"
  }

  private var isVisited: Bool {
    appState.visitedCodes.contains("JP")
  }

  private var removalPrompt: String {
    L10n.text("japan_detail.remove_prompt")
  }

  private var removalButtonTitle: String {
    appState.visitedPrefectureCount > 0
      ? L10n.text("japan_detail.remove_all")
      : L10n.text("country_list.remove_visited")
  }
}
