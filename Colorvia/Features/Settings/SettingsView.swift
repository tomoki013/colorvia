import SwiftUI

struct SettingsView: View {
  @Environment(AppState.self) private var appState
  @Environment(AdMobConsentManager.self) private var consentManager
  @Environment(\.dismiss) private var dismiss
  @State private var confirmingReset = false

  var body: some View {
    NavigationStack {
      List {
        personalizationSection
        dataSection
        supportSection
        informationSection
        copyrightText
        developerLinksSection
      }
      .scrollContentBackground(.hidden)
      .background(ColorviaTheme.background)
      .navigationTitle(L10n.text("settings.title"))
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button {
            dismiss()
          } label: {
            Image(systemName: "xmark")
          }
          .accessibilityLabel(L10n.text("common.close"))
        }
      }
      .confirmationDialog(L10n.text("settings.reset_confirm"), isPresented: $confirmingReset) {
        Button(L10n.text("common.delete"), role: .destructive) {
          Task {
            await appState.resetAllData()
            dismiss()
          }
        }
      }
    }
    .presentationDetents([.large])
    .presentationDragIndicator(.visible)
    .presentationContentInteraction(.scrolls)
    .tint(ColorviaTheme.accentDeep)
    .preferredColorScheme(appState.appearance.colorScheme)
  }

  private var personalizationSection: some View {
    Section(L10n.text("settings.personalization")) {
      HStack {
        Label(L10n.text("settings.theme"), systemImage: "circle.lefthalf.filled")
        Spacer()
        Picker(
          L10n.text("settings.theme"),
          selection: Binding(
            get: { appState.appearance },
            set: { appState.setAppearance($0) }
          )
        ) {
          ForEach(AppearancePreference.allCases, id: \.self) { appearance in
            Text(appearance.localizedName).tag(appearance)
          }
        }
        .labelsHidden()
        .pickerStyle(.menu)
      }
      HStack {
        Label(L10n.text("settings.map_color"), systemImage: "paintpalette")
        Spacer()
        Picker(
          L10n.text("settings.map_color"),
          selection: Binding(
            get: { appState.mapColor },
            set: { appState.setMapColor($0) }
          )
        ) {
          ForEach(MapColorPreference.allCases, id: \.self) { mapColor in
            HStack {
              Circle()
                .fill(mapColor.color)
                .frame(width: 10, height: 10)
              Text(mapColor.localizedName)
            }
            .tag(mapColor)
          }
        }
        .labelsHidden()
        .pickerStyle(.menu)
      }
      Button {
        openAppSettings()
      } label: {
        settingLinkRow(
          icon: "character.bubble",
          title: L10n.text("settings.language"),
          subtitle: Locale.current.localizedString(forLanguageCode: currentLanguageCode)
        )
      }
    }
  }

  private var dataSection: some View {
    Section {
      NavigationLink {
        DataManagementView {
          confirmingReset = true
        }
      } label: {
        settingLinkRow(
          icon: "externaldrive",
          title: L10n.text("settings.data_management"),
          subtitle: L10n.countryCount(appState.visitedCountryCount),
          showsExternalIndicator: false
        )
      }
    }
  }

  private var supportSection: some View {
    Section(L10n.text("settings.support")) {
      NavigationLink {
        InAppArticleView(page: .guide)
      } label: {
        internalRow(icon: "book.closed", title: L10n.text("settings.guide"))
      }
      NavigationLink {
        InAppArticleView(page: .faq)
      } label: {
        internalRow(icon: "questionmark.circle", title: L10n.text("settings.faq"))
      }
      NavigationLink {
        ContactSupportView()
      } label: {
        internalRow(icon: "envelope", title: L10n.text("settings.contact"))
      }
      NavigationLink {
        InAppArticleView(page: .updates)
      } label: {
        internalRow(icon: "sparkles", title: L10n.text("settings.updates"))
      }
    }
  }

  private var informationSection: some View {
    Section(L10n.text("settings.information")) {
      NavigationLink {
        AppDetailsView()
      } label: {
        settingLinkRow(
          icon: "info.circle",
          title: L10n.text("settings.app_details"),
          showsExternalIndicator: false
        )
      }
      if consentManager.isPrivacyOptionsRequired {
        Button {
          Task { await consentManager.presentPrivacyOptions() }
        } label: {
          settingLinkRow(
            icon: "hand.raised.circle",
            title: L10n.text("settings.privacy_choices"),
            showsExternalIndicator: false
          )
        }
      }
      NavigationLink {
        LegalDocumentView(
          title: L10n.text("settings.privacy"),
          url: SupportAPIConfiguration.privacyPolicy,
          sections: InAppArticlePage.privacy.sections
        )
      } label: {
        internalRow(icon: "hand.raised", title: L10n.text("settings.privacy"))
      }
      NavigationLink {
        LegalDocumentView(
          title: L10n.text("settings.terms"),
          url: SupportAPIConfiguration.termsOfService,
          sections: InAppArticlePage.terms.sections
        )
      } label: {
        internalRow(icon: "doc.text", title: L10n.text("settings.terms"))
      }
      NavigationLink {
        LegalDocumentView(
          title: InAppArticlePage.commercial.title,
          url: SupportAPIConfiguration.commercialTransactions,
          sections: InAppArticlePage.commercial.sections
        )
      } label: {
        internalRow(icon: "building.columns", title: InAppArticlePage.commercial.title)
      }
      NavigationLink {
        OpenSourceLicensesView()
      } label: {
        settingLinkRow(
          icon: "chevron.left.forwardslash.chevron.right",
          title: L10n.text("settings.licenses"),
          showsExternalIndicator: false
        )
      }
    }
  }

  private var copyrightText: some View {
    Text("©︎ Colorvia")
      .font(.footnote)
      .foregroundStyle(ColorviaTheme.secondaryInk)
      .frame(maxWidth: .infinity)
      .listRowBackground(Color.clear)
      .listRowSeparator(.hidden)
      .padding(.top, 6)
  }

  private var developerLinksSection: some View {
    Section {
      externalRow(
        icon: "person.crop.circle",
        title: L10n.text("settings.developer_site"),
        subtitle: "tomokichi.dev",
        url: "https://tomokichi.dev"
      )
      externalRow(
        icon: "building.2",
        title: L10n.text("settings.app_studio"),
        subtitle: "tmkch.io",
        url: "https://tmkch.io"
      )
    }
  }

  private func internalRow(icon: String, title: String) -> some View {
    settingLinkRow(
      icon: icon,
      title: title,
      showsExternalIndicator: false
    )
  }

  private func settingValueRow(icon: String, title: String, value: String) -> some View {
    LabeledContent {
      Text(value)
        .foregroundStyle(ColorviaTheme.secondaryInk)
    } label: {
      Label(title, systemImage: icon)
    }
  }

  private func settingLinkRow(
    icon: String,
    title: String,
    subtitle: String? = nil,
    destructive: Bool = false,
    showsExternalIndicator: Bool = true
  ) -> some View {
    HStack(spacing: 12) {
      Image(systemName: icon)
        .frame(width: 22)
      Text(title)
      Spacer()
      if let subtitle {
        Text(subtitle)
          .font(.subheadline)
          .foregroundStyle(ColorviaTheme.secondaryInk)
          .lineLimit(1)
      }
      if showsExternalIndicator {
        Image(systemName: "arrow.up.right")
          .font(.caption.weight(.semibold))
          .foregroundStyle(ColorviaTheme.secondaryInk)
      }
    }
    .foregroundStyle(destructive ? Color.red : ColorviaTheme.ink)
  }

  private func externalRow(
    icon: String,
    title: String,
    subtitle: String? = nil,
    url: String
  ) -> some View {
    Link(destination: URL(string: url)!) {
      settingLinkRow(icon: icon, title: title, subtitle: subtitle)
    }
  }

  private var currentLanguageCode: String {
    Locale.current.language.languageCode?.identifier ?? "en"
  }

  private func openAppSettings() {
    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
    UIApplication.shared.open(url)
  }
}

private struct AppDetailsView: View {
  var body: some View {
    List {
      Section {
        Link(destination: URL(string: "https://colorvia.tmkch.io")!) {
          LabeledContent(L10n.text("settings.official_site"), value: "colorvia.tmkch.io")
        }
        LabeledContent(L10n.text("settings.version"), value: appVersion)
        Link(destination: URL(string: "mailto:support@tmkch.io?subject=Colorvia")!) {
          LabeledContent(L10n.text("settings.email"), value: "support@tmkch.io")
        }
      }
    }
    .scrollContentBackground(.hidden)
    .background(ColorviaTheme.background)
    .navigationTitle(L10n.text("settings.app_details"))
    .navigationBarTitleDisplayMode(.inline)
  }

  private var appVersion: String {
    Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
  }
}

private struct DataManagementView: View {
  @Environment(AppState.self) private var appState
  @State private var exportDocument = VisitDataDocument()
  @State private var showingExporter = false
  @State private var showingImporter = false
  @State private var resultMessage: String?
  @State private var pendingImportData: Data?
  @State private var orphanedParentCodes: [String] = []
  let onRequestReset: () -> Void

  var body: some View {
    List {
      Section {
        Button {
          do {
            exportDocument = VisitDataDocument(data: try appState.exportedVisitData())
            showingExporter = true
          } catch {
            resultMessage = error.localizedDescription
          }
        } label: {
          Label(L10n.text("settings.export_json"), systemImage: "square.and.arrow.up")
        }

        Button {
          showingImporter = true
        } label: {
          Label(L10n.text("settings.import_json"), systemImage: "square.and.arrow.down")
        }
      } footer: {
        Text(L10n.text("settings.json_footer"))
      }

      Section {
        Button(L10n.text("settings.reset_all"), role: .destructive) {
          onRequestReset()
        }
      } footer: {
        Text(L10n.text("settings.data_management_footer"))
      }
    }
    .scrollContentBackground(.hidden)
    .background(ColorviaTheme.background)
    .navigationTitle(L10n.text("settings.data_management"))
    .navigationBarTitleDisplayMode(.inline)
    .fileExporter(
      isPresented: $showingExporter,
      document: exportDocument,
      contentType: .json,
      defaultFilename: "colorvia-visits"
    ) { result in
      if case .failure(let error) = result {
        resultMessage = error.localizedDescription
      }
    }
    .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.json]) { result in
      switch result {
      case .success(let url):
        Task {
          let accessed = url.startAccessingSecurityScopedResource()
          defer {
            if accessed { url.stopAccessingSecurityScopedResource() }
          }
          do {
            let data = try Data(contentsOf: url)
            do {
              try await appState.importVisitData(data)
            } catch VisitDataImportError.unvisitedParentCountries(let codes) {
              pendingImportData = data
              orphanedParentCodes = codes
              return
            }
            resultMessage = L10n.text("settings.import_complete")
          } catch {
            resultMessage = error.localizedDescription
          }
        }
      case .failure(let error):
        resultMessage = error.localizedDescription
      }
    }
    .alert(
      L10n.text("settings.data_management"),
      isPresented: Binding(
        get: { resultMessage != nil },
        set: { if !$0 { resultMessage = nil } }
      )
    ) {
      Button("OK", role: .cancel) {}
    } message: {
      Text(resultMessage ?? "")
    }
    .confirmationDialog(
      L10n.text("settings.import_parent_title"),
      isPresented: Binding(
        get: { pendingImportData != nil },
        set: {
          if !$0 {
            pendingImportData = nil
            orphanedParentCodes = []
          }
        }
      ),
      titleVisibility: .visible
    ) {
      Button(L10n.text("settings.import_repair_parents")) {
        completePendingImport(repairParents: true)
      }
      Button(L10n.text("settings.import_skip_regions")) {
        completePendingImport(repairParents: false)
      }
      Button(L10n.text("common.cancel"), role: .cancel) {}
    } message: {
      Text(orphanedParentCodes.joined(separator: ", "))
    }
  }

  private func completePendingImport(repairParents: Bool) {
    guard let data = pendingImportData else { return }
    pendingImportData = nil
    Task {
      do {
        try await appState.importVisitData(data, repairUnvisitedParents: repairParents)
        resultMessage = L10n.text("settings.import_complete")
      } catch {
        resultMessage = error.localizedDescription
      }
      orphanedParentCodes = []
    }
  }
}

private struct OpenSourceLicensesView: View {
  var body: some View {
    List {
      Section(L10n.text("settings.admob_license_title")) {
        Text(L10n.text("settings.admob_license_description"))
          .font(.subheadline)
          .foregroundStyle(ColorviaTheme.secondaryInk)
        Link(
          L10n.text("settings.view_source"),
          destination: URL(string: "https://developers.google.com/admob/ios/download")!
        )
      }
      Section("Natural Earth") {
        Text(L10n.text("settings.natural_earth_description"))
          .font(.subheadline)
          .foregroundStyle(ColorviaTheme.secondaryInk)
        Link(
          L10n.text("settings.view_source"),
          destination: URL(string: "https://www.naturalearthdata.com/")!
        )
      }
      Section("Insee COG 2026") {
        Text(L10n.text("settings.insee_description"))
          .font(.subheadline)
          .foregroundStyle(ColorviaTheme.secondaryInk)
        Link(
          L10n.text("settings.view_source"),
          destination: URL(string: "https://www.insee.fr/fr/information/8740222")!
        )
      }
      Section("Geolonia Japanese Addresses") {
        Text(L10n.text("settings.japan_address_description"))
          .font(.subheadline)
          .foregroundStyle(ColorviaTheme.secondaryInk)
        Link(
          L10n.text("settings.view_source"),
          destination: URL(string: "https://github.com/geolonia/japanese-addresses")!
        )
      }
      Section("GeoNames") {
        Text(L10n.text("settings.geonames_description"))
          .font(.subheadline)
          .foregroundStyle(ColorviaTheme.secondaryInk)
        Link(
          L10n.text("settings.view_source"),
          destination: URL(string: "https://www.geonames.org/")!
        )
      }
      Section("U.S. Census Bureau") {
        Text(L10n.text("settings.us_census_description"))
          .font(.subheadline)
          .foregroundStyle(ColorviaTheme.secondaryInk)
        Link(
          L10n.text("settings.view_source"),
          destination: URL(
            string:
              "https://www.census.gov/geographies/mapping-files/time-series/geo/cartographic-boundary.html"
          )!
        )
      }
      Section("Singapore URA") {
        Text(L10n.text("settings.singapore_ura_description"))
          .font(.subheadline)
          .foregroundStyle(ColorviaTheme.secondaryInk)
        Link(
          L10n.text("settings.view_source"),
          destination: URL(
            string: "https://data.gov.sg/datasets/d_4765db0e87b9c86336792efe8a1f7a66/view"
          )!
        )
      }
    }
    .scrollContentBackground(.hidden)
    .background(ColorviaTheme.background)
    .navigationTitle(L10n.text("settings.licenses"))
    .navigationBarTitleDisplayMode(.inline)
  }
}

private enum InAppArticlePage {
  case guide
  case faq
  case updates
  case privacy
  case terms
  case commercial

  var title: String {
    switch self {
    case .guide: L10n.text("settings.guide")
    case .faq: L10n.text("settings.faq")
    case .updates: L10n.text("settings.updates")
    case .privacy: L10n.text("settings.privacy")
    case .terms: L10n.text("settings.terms")
    case .commercial:
      localizedLegalText(
        english: "Commercial transactions disclosure",
        japanese: "特定商取引法に基づく表記"
      )
    }
  }

  var sections: [(title: String, body: String)] {
    switch self {
    case .guide:
      [
        (
          L10n.text("guide.start.title"),
          L10n.text("guide.start.body")
        ),
        (
          L10n.text("guide.add.title"),
          L10n.text("guide.add.body")
        ),
        (
          L10n.text("guide.map.title"),
          L10n.text("guide.map.body")
        ),
      ]
    case .faq:
      [
        (
          L10n.text("faq.account.title"),
          L10n.text("faq.account.body")
        ),
        (
          L10n.text("faq.storage.title"),
          L10n.text("faq.storage.body")
        ),
        (
          L10n.text("faq.percentage.title"),
          L10n.text("faq.percentage.body")
        ),
      ]
    case .updates:
      [
        (
          L10n.text("updates.version.title"),
          L10n.text("updates.version.body")
        )
      ]
    case .privacy:
      [
        (
          L10n.text("privacy.collection.title"),
          L10n.text("privacy.collection.body")
        ),
        (
          L10n.text("privacy.storage.title"),
          L10n.text("privacy.storage.body")
        ),
        (
          L10n.text("privacy.ads.title"),
          L10n.text("privacy.ads.body")
        ),
        (
          L10n.text("privacy.analytics.title"),
          L10n.text("privacy.analytics.body")
        ),
      ]
    case .terms:
      [
        (
          L10n.text("terms.service.title"),
          L10n.text("terms.service.body")
        ),
        (
          L10n.text("terms.use.title"),
          L10n.text("terms.use.body")
        ),
        (
          L10n.text("terms.disclaimer.title"),
          L10n.text("terms.disclaimer.body")
        ),
      ]
    case .commercial:
      [
        (
          localizedLegalText(
            english: "Latest disclosure",
            japanese: "最新の表記"
          ),
          localizedLegalText(
            english: "Connect to the internet to view the current commercial transactions disclosure on the official Colorvia website.",
            japanese: "公式Colorviaサイトで最新の特定商取引法に基づく表記を確認するには、インターネットに接続してください。"
          )
        )
      ]
    }
  }
}

private struct InAppArticleView: View {
  let page: InAppArticlePage

  var body: some View {
    ScrollView {
      LazyVStack(alignment: .leading, spacing: 16) {
        ForEach(Array(page.sections.enumerated()), id: \.offset) { _, section in
          VStack(alignment: .leading, spacing: 9) {
            Text(section.title)
              .font(.headline)
              .foregroundStyle(ColorviaTheme.ink)
            Text(section.body)
              .font(.body)
              .foregroundStyle(ColorviaTheme.secondaryInk)
              .fixedSize(horizontal: false, vertical: true)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(18)
          .background(ColorviaTheme.card, in: RoundedRectangle(cornerRadius: 20))
        }
      }
      .padding(20)
    }
    .background(ColorviaTheme.background)
    .navigationTitle(page.title)
    .navigationBarTitleDisplayMode(.inline)
  }
}
