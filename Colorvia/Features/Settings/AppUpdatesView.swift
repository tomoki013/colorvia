import SwiftUI

/// One shipped version of Colorvia, as it appears in the release ledger.
struct AppRelease: Identifiable {
  let version: String
  let released: Date
  let summary: String
  let changes: [String]

  var id: String { version }
}

extension AppRelease {
  /// Every version that has reached the App Store, newest first.
  ///
  /// Deliberately only releases. Site launches, previews and other
  /// announcements are news about Colorvia rather than changes to it, and
  /// mixing them in makes the ledger useless for its one job: telling you what
  /// is different in the app you are holding.
  static let all: [AppRelease] = [
    AppRelease(
      version: "1.0.1",
      released: DateComponents(calendar: .current, year: 2026, month: 8, day: 27).date ?? .now,
      summary: L10n.text("updates.v1_0_1.summary"),
      changes: [
        L10n.text("updates.v1_0_1.change1"),
        L10n.text("updates.v1_0_1.change2"),
        L10n.text("updates.v1_0_1.change3"),
        L10n.text("updates.v1_0_1.change4"),
        L10n.text("updates.v1_0_1.change5"),
        L10n.text("updates.v1_0_1.change6"),
      ]
    ),
    AppRelease(
      version: "1.0.0",
      released: DateComponents(calendar: .current, year: 2026, month: 8, day: 17).date ?? .now,
      summary: L10n.text("updates.v1_0_0.summary"),
      changes: [
        L10n.text("updates.v1_0_0.change1"),
        L10n.text("updates.v1_0_0.change2"),
        L10n.text("updates.v1_0_0.change3"),
        L10n.text("updates.v1_0_0.change4"),
        L10n.text("updates.v1_0_0.change5"),
        L10n.text("updates.v1_0_0.change6"),
        L10n.text("updates.v1_0_0.change7"),
      ]
    ),
  ]
}

/// The release ledger: what changed, version by version. Mirrors the ledger on
/// the brand site so the two never disagree about what shipped when.
struct AppUpdatesView: View {
  let releases: [AppRelease]

  init(releases: [AppRelease] = AppRelease.all) {
    self.releases = releases
  }

  var body: some View {
    ScrollView {
      LazyVStack(alignment: .leading, spacing: 20) {
        Text(L10n.text("updates.intro"))
          .font(.subheadline)
          .foregroundStyle(ColorviaTheme.secondaryInk)
          .fixedSize(horizontal: false, vertical: true)
          .padding(.bottom, 4)

        ForEach(Array(releases.enumerated()), id: \.element.id) { index, release in
          releaseCard(release, isLatest: index == 0)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(20)
    }
    .background(ColorviaTheme.background)
    .navigationTitle(L10n.text("settings.updates"))
    .navigationBarTitleDisplayMode(.inline)
  }

  private func releaseCard(_ release: AppRelease, isLatest: Bool) -> some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack(alignment: .firstTextBaseline) {
        VStack(alignment: .leading, spacing: 6) {
          Text(isLatest ? L10n.text("updates.latest") : L10n.text("updates.earlier"))
            .font(.caption2.weight(.bold))
            .textCase(.uppercase)
            .foregroundStyle(ColorviaTheme.accentDeep)
          Text(verbatim: "Version \(release.version)")
            .font(.title3.weight(.semibold))
            .foregroundStyle(ColorviaTheme.ink)
        }
        Spacer(minLength: 12)
        Text(release.released, format: .dateTime.year().month(.abbreviated).day())
          .font(.caption)
          .foregroundStyle(ColorviaTheme.secondaryInk)
          .padding(.horizontal, 10)
          .padding(.vertical, 5)
          .background(
            ColorviaTheme.accent.opacity(0.12),
            in: RoundedRectangle(cornerRadius: 999, style: .continuous)
          )
      }

      Text(release.summary)
        .font(.subheadline)
        .foregroundStyle(ColorviaTheme.ink)
        .fixedSize(horizontal: false, vertical: true)

      Divider()
        .overlay(ColorviaTheme.border.opacity(0.4))

      VStack(alignment: .leading, spacing: 10) {
        ForEach(Array(release.changes.enumerated()), id: \.offset) { _, change in
          HStack(alignment: .firstTextBaseline, spacing: 10) {
            Circle()
              .fill(ColorviaTheme.accent)
              .frame(width: 5, height: 5)
              .alignmentGuide(.firstTextBaseline) { _ in 4 }
            Text(change)
              .font(.footnote)
              .foregroundStyle(ColorviaTheme.secondaryInk)
              .fixedSize(horizontal: false, vertical: true)
          }
        }
      }
      .accessibilityElement(children: .contain)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(20)
    .background(ColorviaTheme.card, in: RoundedRectangle(cornerRadius: 20))
  }
}
