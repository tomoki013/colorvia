import SwiftUI

struct SettingsView: View {
  @Environment(AppState.self) private var appState
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
      .toolbar { Button(L10n.text("common.close")) { dismiss() } }
      .confirmationDialog(L10n.text("settings.reset_confirm"), isPresented: $confirmingReset) {
        Button(L10n.text("common.delete"), role: .destructive) {
          Task {
            await appState.resetAllData()
            dismiss()
          }
        }
      }
    }
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
      NavigationLink {
        InAppArticleView(page: .privacy)
      } label: {
        internalRow(icon: "hand.raised", title: L10n.text("settings.privacy"))
      }
      NavigationLink {
        InAppArticleView(page: .terms)
      } label: {
        internalRow(icon: "doc.text", title: L10n.text("settings.terms"))
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
  let onRequestReset: () -> Void

  var body: some View {
    List {
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
  }
}

private struct OpenSourceLicensesView: View {
  var body: some View {
    List {
      Section("Natural Earth") {
        Text(L10n.text("settings.natural_earth_description"))
          .font(.subheadline)
          .foregroundStyle(ColorviaTheme.secondaryInk)
        Link(
          L10n.text("settings.view_source"),
          destination: URL(string: "https://www.naturalearthdata.com/")!
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

  var title: String {
    switch self {
    case .guide: L10n.text("settings.guide")
    case .faq: L10n.text("settings.faq")
    case .updates: L10n.text("settings.updates")
    case .privacy: L10n.text("settings.privacy")
    case .terms: L10n.text("settings.terms")
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

private struct ContactSupportView: View {
  @State private var email = ""
  @State private var message = ""
  @State private var showingSentMessage = false

  var body: some View {
    Form {
      Section {
        TextField(L10n.text("contact.email_placeholder"), text: $email)
          .textContentType(.emailAddress)
          .keyboardType(.emailAddress)
          .textInputAutocapitalization(.never)

        TextEditor(text: $message)
          .frame(minHeight: 150)
          .overlay(alignment: .topLeading) {
            if message.isEmpty {
              Text(L10n.text("contact.message_placeholder"))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 5)
                .padding(.vertical, 8)
                .allowsHitTesting(false)
            }
          }
      } header: {
        Text(L10n.text("contact.form_title"))
      } footer: {
        Text(L10n.text("contact.footer"))
      }

      Section {
        Button(L10n.text("contact.send")) {
          showingSentMessage = true
        }
        .frame(maxWidth: .infinity)
        .disabled(email.isEmpty || message.isEmpty)
      }
    }
    .scrollContentBackground(.hidden)
    .background(ColorviaTheme.background)
    .navigationTitle(L10n.text("settings.contact"))
    .navigationBarTitleDisplayMode(.inline)
    .alert(L10n.text("contact.sent_title"), isPresented: $showingSentMessage) {
      Button(L10n.text("common.close"), role: .cancel) {}
    } message: {
      Text(L10n.text("contact.sent_body"))
    }
  }
}
