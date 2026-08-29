import SwiftUI
import UIKit

struct WorldShareSheet: View {
  @Environment(\.dismiss) private var dismiss
  let countries: [MapCountry]
  let visitedCodes: Set<String>
  let visitedCount: Int
  let visitedColor: Color

  @State private var renderedImages: [WorldPosterVariant: UIImage] = [:]
  @State private var sharePayload: ColorviaSharePayload?
  @State private var renderError: String?

  var body: some View {
    NavigationStack {
      List {
        Section(L10n.text("world_share.full_poster")) {
          shareRow(.square)
          shareRow(.story)
        }
        Section(L10n.text("subdivision_share.map_only")) {
          shareRow(.mapSquare)
          shareRow(.mapStory)
        }
      }
      .navigationTitle(L10n.text("world_share.title"))
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
    .sheet(item: $sharePayload) { payload in
      ColorviaActivityShareSheet(payload: payload)
        .presentationDetents([.large])
    }
    .alert(
      L10n.text("world_share.title"),
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
  private func shareRow(_ variant: WorldPosterVariant) -> some View {
    if let image = renderedImages[variant] {
      Button {
        sharePayload = ColorviaSharePayload(
          image: image,
          message: L10n.shareMessage(visitedCount)
        )
      } label: {
        Label {
          VStack(alignment: .leading, spacing: 3) {
            Text(variant.isStory ? "1080 × 1920" : "1080 × 1080")
            Text(
              variant.isStory
                ? L10n.text("subdivision_share.story")
                : L10n.text("subdivision_share.square")
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
      for variant in WorldPosterVariant.allCases {
        renderedImages[variant] = try WorldPosterRenderer.render(
          countries: countries,
          visitedCodes: visitedCodes,
          visitedCount: visitedCount,
          visitedColor: visitedColor,
          variant: variant
        )
      }
    } catch {
      renderError = error.localizedDescription
    }
  }
}

private enum WorldPosterVariant: CaseIterable, Hashable {
  case square
  case story
  case mapSquare
  case mapStory

  var isStory: Bool { self == .story || self == .mapStory }
  var isMapOnly: Bool { self == .mapSquare || self == .mapStory }
  var size: CGSize {
    isStory ? CGSize(width: 540, height: 960) : CGSize(width: 540, height: 540)
  }
}

@MainActor
private enum WorldPosterRenderer {
  static func render(
    countries: [MapCountry],
    visitedCodes: Set<String>,
    visitedCount: Int,
    visitedColor: Color,
    variant: WorldPosterVariant
  ) throws -> UIImage {
    let content = WorldPosterView(
      countries: countries,
      visitedCodes: visitedCodes,
      visitedCount: visitedCount,
      visitedColor: visitedColor,
      variant: variant
    )
    .frame(width: variant.size.width, height: variant.size.height)
    let renderer = ImageRenderer(content: content)
    renderer.proposedSize = ProposedViewSize(variant.size)
    renderer.scale = 2
    guard let image = renderer.uiImage else {
      throw CocoaError(.fileWriteUnknown)
    }
    return image
  }
}

private struct WorldPosterView: View {
  let countries: [MapCountry]
  let visitedCodes: Set<String>
  let visitedCount: Int
  let visitedColor: Color
  let variant: WorldPosterVariant

  private var titleText: String { "MY WORLD" }

  var body: some View {
    VStack(spacing: variant.isStory ? 48 : 24) {
      if !variant.isMapOnly {
        header
      }

      posterMap
        .frame(height: mapHeight)

      if variant.isMapOnly {
        Text("Colorvia")
          .font(.system(size: 17, weight: .semibold, design: .serif))
          .foregroundStyle(posterSecondary)
      } else {
        stats
      }
    }
    .padding(.horizontal, variant.isStory ? 38 : 30)
    .padding(.vertical, variant.isStory ? 78 : 34)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(red: 0.95, green: 0.97, blue: 0.95))
    .foregroundStyle(Color(red: 0.10, green: 0.19, blue: 0.20))
  }

  private var header: some View {
    VStack(spacing: 6) {
      Text(titleText)
        .font(.system(size: variant.isStory ? 38 : 30, weight: .bold, design: .rounded))
      Text("COLORVIA")
        .font(.system(size: 10, weight: .semibold, design: .rounded))
        .tracking(3)
        .foregroundStyle(posterSecondary)
    }
  }

  private var stats: some View {
    VStack(spacing: 7) {
      Text("\(visitedCount) / 195 \(L10n.countryUnit(visitedCount).uppercased())")
        .font(.system(size: 22, weight: .semibold, design: .rounded))
        .minimumScaleFactor(0.7)
      Text(
        (Double(visitedCount) / 195 * 100)
          .formatted(.number.precision(.fractionLength(1))) + "%"
      )
      .font(.system(size: 16, weight: .medium, design: .rounded))
      .foregroundStyle(posterSecondary)
    }
  }

  private var posterMap: some View {
    Canvas { context, size in
      let ratio: CGFloat = 2.05
      let width = min(size.width * 0.94, size.height * ratio)
      let height = width / ratio
      let mapRect = CGRect(
        x: (size.width - width) / 2,
        y: (size.height - height) / 2,
        width: width,
        height: height
      )
      for country in countries {
        let path = Path { path in
          for polygon in country.polygons where polygon.count > 2 {
            let first = polygon[0]
            path.move(
              to: CGPoint(
                x: mapRect.minX + first.x * mapRect.width,
                y: mapRect.minY + first.y * mapRect.height
              )
            )
            for point in polygon.dropFirst() {
              path.addLine(
                to: CGPoint(
                  x: mapRect.minX + point.x * mapRect.width,
                  y: mapRect.minY + point.y * mapRect.height
                )
              )
            }
            path.closeSubpath()
          }
        }
        context.fill(
          path,
          with: .color(
            visitedCodes.contains(country.code)
              ? visitedColor : Color(red: 0.83, green: 0.87, blue: 0.83)
          )
        )
        context.stroke(path, with: .color(.white.opacity(0.82)), lineWidth: 0.45)
      }
    }
    .background(Color(red: 0.83, green: 0.92, blue: 0.92))
    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
  }

  private var mapHeight: CGFloat {
    if variant.isMapOnly { return variant.isStory ? 700 : 405 }
    return variant.isStory ? 480 : 285
  }

  private var posterSecondary: Color {
    Color(red: 0.22, green: 0.42, blue: 0.43)
  }
}
