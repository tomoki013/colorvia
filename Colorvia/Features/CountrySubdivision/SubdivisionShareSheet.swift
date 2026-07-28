import SwiftUI

struct SubdivisionShareSheet: View {
  @Environment(\.dismiss) private var dismiss
  let definition: CountrySubdivisionDefinition
  let geometry: [MapPrefecture]
  let visitedCodes: Set<String>
  let visitedColor: Color
  @State private var renderedURLs: [SubdivisionPosterVariant: URL] = [:]
  @State private var renderError: String?

  var body: some View {
    NavigationStack {
      List {
        Section(L10n.text("subdivision_share.country_map")) {
          shareRow(.countrySquare)
          shareRow(.countryStory)
        }
        Section(L10n.text("subdivision_share.map_only")) {
          shareRow(.mapSquare)
          shareRow(.mapStory)
        }
      }
      .navigationTitle(L10n.text("subdivision_share.title"))
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
    }
    .presentationDetents([.medium, .large])
    .presentationDragIndicator(.visible)
    .task { renderPosters() }
    .alert(
      L10n.text("subdivision_share.title"),
      isPresented: Binding(
        get: { renderError != nil },
        set: { if !$0 { renderError = nil } }
      )
    ) {
      Button("OK", role: .cancel) {}
    } message: {
      Text(renderError ?? "")
    }
  }

  @ViewBuilder
  private func shareRow(_ variant: SubdivisionPosterVariant) -> some View {
    if let url = renderedURLs[variant] {
      ShareLink(
        item: url,
        preview: SharePreview(
          definition.localizedCountryName,
          image: Image(systemName: variant.isStory ? "rectangle.portrait" : "square")
        )
      ) {
        Label {
          VStack(alignment: .leading, spacing: 3) {
            Text(variant.isStory ? "1080 × 1920" : "1080 × 1080")
            Text(
              variant.isStory
                ? L10n.text("subdivision_share.story") : L10n.text("subdivision_share.square")
            )
            .font(.caption)
            .foregroundStyle(.secondary)
          }
        } icon: {
          Image(systemName: variant.isStory ? "rectangle.portrait" : "square")
        }
      }
    } else {
      HStack {
        Label(
          variant.isStory ? "1080 × 1920" : "1080 × 1080",
          systemImage: variant.isStory ? "rectangle.portrait" : "square"
        )
        Spacer()
        ProgressView()
      }
    }
  }

  @MainActor
  private func renderPosters() {
    do {
      for variant in SubdivisionPosterVariant.allCases {
        renderedURLs[variant] = try SubdivisionPosterRenderer.render(
          definition: definition,
          geometry: geometry,
          visitedCodes: visitedCodes,
          visitedColor: visitedColor,
          variant: variant
        )
      }
    } catch {
      renderError = error.localizedDescription
    }
  }
}

private enum SubdivisionPosterVariant: String, CaseIterable {
  case countrySquare
  case countryStory
  case mapSquare
  case mapStory

  var isStory: Bool {
    self == .countryStory || self == .mapStory
  }

  var isMapOnly: Bool {
    self == .mapSquare || self == .mapStory
  }

  var size: CGSize {
    isStory ? CGSize(width: 540, height: 960) : CGSize(width: 540, height: 540)
  }
}

@MainActor
private enum SubdivisionPosterRenderer {
  static func render(
    definition: CountrySubdivisionDefinition,
    geometry: [MapPrefecture],
    visitedCodes: Set<String>,
    visitedColor: Color,
    variant: SubdivisionPosterVariant
  ) throws -> URL {
    let content = SubdivisionPosterView(
      definition: definition,
      geometry: geometry,
      visitedCodes: visitedCodes,
      visitedColor: visitedColor,
      variant: variant
    )
    .frame(width: variant.size.width, height: variant.size.height)
    let renderer = ImageRenderer(content: content)
    renderer.proposedSize = ProposedViewSize(variant.size)
    renderer.scale = 2
    guard let data = renderer.uiImage?.pngData() else {
      throw CocoaError(.fileWriteUnknown)
    }
    let url = FileManager.default.temporaryDirectory.appending(
      path: "colorvia-\(definition.countryCode.lowercased())-\(variant.rawValue).png"
    )
    try data.write(to: url, options: .atomic)
    return url
  }
}

private struct SubdivisionPosterView: View {
  let definition: CountrySubdivisionDefinition
  let geometry: [MapPrefecture]
  let visitedCodes: Set<String>
  let visitedColor: Color
  let variant: SubdivisionPosterVariant

  var body: some View {
    VStack(spacing: variant.isStory ? 44 : 20) {
      if !variant.isMapOnly {
        VStack(spacing: 5) {
          Text("MY \(englishCountryName.uppercased())")
            .font(.system(size: variant.isStory ? 34 : 27, weight: .bold, design: .rounded))
          Text("COLORVIA")
            .font(.system(size: 10, weight: .semibold, design: .rounded))
            .tracking(3)
            .foregroundStyle(posterSecondary)
        }
      }

      posterMap
        .frame(height: mapHeight)

      if !variant.isMapOnly {
        VStack(spacing: 7) {
          Text(
            "\(visitedCodes.count) / \(definition.totalCount) \(definition.nativeUnitName.uppercased())"
          )
          .font(.system(size: 21, weight: .semibold, design: .rounded))
          .minimumScaleFactor(0.7)
          Text(
            (Double(visitedCodes.count) / Double(definition.totalCount) * 100)
              .formatted(.number.precision(.fractionLength(1))) + "%"
          )
          .font(.system(size: 15, weight: .medium, design: .rounded))
          .foregroundStyle(posterSecondary)
        }
      } else {
        Text("Colorvia")
          .font(.system(size: 15, weight: .semibold, design: .serif))
          .foregroundStyle(posterSecondary)
      }
    }
    .padding(.horizontal, 38)
    .padding(.vertical, variant.isStory ? 76 : 30)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(red: 0.95, green: 0.97, blue: 0.95))
    .foregroundStyle(Color(red: 0.10, green: 0.19, blue: 0.20))
  }

  private var posterMap: some View {
    Canvas { context, size in
      let side = min(size.width, size.height)
      let rect = CGRect(
        x: (size.width - side) / 2,
        y: (size.height - side) / 2,
        width: side,
        height: side
      )
      for subdivision in geometry {
        let path = Path { path in
          for polygon in subdivision.polygons where polygon.count > 2 {
            let first = polygon[0]
            path.move(
              to: CGPoint(
                x: rect.minX + first.x * rect.width,
                y: rect.minY + first.y * rect.height
              )
            )
            for point in polygon.dropFirst() {
              path.addLine(
                to: CGPoint(
                  x: rect.minX + point.x * rect.width,
                  y: rect.minY + point.y * rect.height
                )
              )
            }
            path.closeSubpath()
          }
        }
        context.fill(
          path,
          with: .color(
            visitedCodes.contains(subdivision.code)
              ? visitedColor : Color(red: 0.83, green: 0.87, blue: 0.83)
          )
        )
        context.stroke(path, with: .color(.white.opacity(0.9)), lineWidth: 0.7)
      }
    }
    .background(Color(red: 0.83, green: 0.92, blue: 0.92))
    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
  }

  private var mapHeight: CGFloat {
    if variant.isMapOnly { return variant.isStory ? 720 : 410 }
    return variant.isStory ? 540 : 330
  }

  private var englishCountryName: String {
    Locale(identifier: "en").localizedString(forRegionCode: definition.countryCode)
      ?? definition.countryCode
  }

  private var posterSecondary: Color {
    Color(red: 0.22, green: 0.42, blue: 0.43)
  }
}
