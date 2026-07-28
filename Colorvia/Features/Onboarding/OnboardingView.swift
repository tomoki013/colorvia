import SwiftUI

struct OnboardingView: View {
  @Environment(AppState.self) private var appState
  @State private var showingPicker = false

  var body: some View {
    VStack(spacing: 0) {
      Text("Colorvia")
        .font(ColorviaTheme.logoFont(size: 46))
        .foregroundStyle(ColorviaTheme.ink)
        .padding(.top, 54)

      WorldMapView(countries: appState.mapCountries, visitedCodes: [], compact: true)
        .frame(maxHeight: 330)
        .padding(.horizontal, 22)
        .padding(.vertical, 34)

      VStack(spacing: 12) {
        Text(L10n.text("onboarding.title"))
          .font(.title2.weight(.semibold))
          .foregroundStyle(ColorviaTheme.ink)
        Text(L10n.text("onboarding.subtitle"))
          .font(.body)
          .foregroundStyle(ColorviaTheme.secondaryInk)
      }

      Spacer()

      Button {
        showingPicker = true
      } label: {
        Text(L10n.text("onboarding.choose_countries"))
          .font(.headline)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 17)
          .foregroundStyle(.white)
          .background(ColorviaTheme.accentDeep, in: Capsule())
      }
      .padding(.horizontal, 28)
      .padding(.bottom, 24)
    }
    .background(ColorviaTheme.background.ignoresSafeArea())
    .sheet(isPresented: $showingPicker) {
      CountryPickerView(initialSelection: []) { selection in
        Task { await appState.completeOnboarding(with: selection) }
      }
    }
  }
}
