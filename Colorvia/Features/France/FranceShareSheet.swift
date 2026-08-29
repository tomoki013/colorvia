import SwiftUI
import UIKit

struct FranceShareSheet: View {
  @Environment(\.dismiss) private var dismiss
  let departments: [MapPrefecture]
  let visitedCodes: Set<String>
  let visitedColor: Color
  @State private var squareImage: UIImage?
  @State private var storyImage: UIImage?
  @State private var sharePayload: ColorviaSharePayload?
  @State private var renderError: String?

  var body: some View {
    NavigationStack {
      List {
        shareRow(
          title: L10n.text("france_share.square"),
          subtitle: "1080 × 1080",
          icon: "square",
          image: squareImage
        )
        shareRow(
          title: L10n.text("france_share.story"),
          subtitle: "1080 × 1920",
          icon: "rectangle.portrait",
          image: storyImage
        )
      }
      .navigationTitle(L10n.text("france_share.title"))
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
    .presentationDetents([.medium])
    .presentationDragIndicator(.visible)
    .task { renderPosters() }
    .sheet(item: $sharePayload) { payload in
      ColorviaActivityShareSheet(payload: payload)
        .presentationDetents([.large])
    }
    .alert(
      L10n.text("france_share.title"),
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
  private func shareRow(
    title: String,
    subtitle: String,
    icon: String,
    image: UIImage?
  ) -> some View {
    if let image {
      Button {
        sharePayload = ColorviaSharePayload(
          image: image,
          message: L10n.franceShareMessage(visitedCodes.count)
        )
      } label: {
        Label {
          VStack(alignment: .leading, spacing: 3) {
            Text(title)
            Text(subtitle)
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        } icon: {
          Image(systemName: icon)
        }
      }
    } else {
      HStack {
        Label {
          VStack(alignment: .leading, spacing: 3) {
            Text(title)
            Text(subtitle)
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        } icon: {
          Image(systemName: icon)
        }
        Spacer()
        ProgressView()
      }
    }
  }

  @MainActor
  private func renderPosters() {
    do {
      squareImage = try FrancePosterRenderer.render(
        departments: departments,
        visitedCodes: visitedCodes,
        visitedColor: visitedColor,
        layout: .square
      )
      storyImage = try FrancePosterRenderer.render(
        departments: departments,
        visitedCodes: visitedCodes,
        visitedColor: visitedColor,
        layout: .story
      )
    } catch {
      renderError = error.localizedDescription
    }
  }
}

private enum FrancePosterLayout {
  case square
  case story

  var logicalSize: CGSize {
    switch self {
    case .square: CGSize(width: 540, height: 540)
    case .story: CGSize(width: 540, height: 960)
    }
  }

}

@MainActor
private enum FrancePosterRenderer {
  static func render(
    departments: [MapPrefecture],
    visitedCodes: Set<String>,
    visitedColor: Color,
    layout: FrancePosterLayout
  ) throws -> UIImage {
    let size = layout.logicalSize
    let content = FrancePosterView(
      departments: departments,
      visitedCodes: visitedCodes,
      visitedColor: visitedColor,
      size: size
    )
    .frame(width: size.width, height: size.height)

    let renderer = ImageRenderer(content: content)
    renderer.proposedSize = ProposedViewSize(size)
    renderer.scale = 2
    guard let image = renderer.uiImage else {
      throw CocoaError(.fileWriteUnknown)
    }
    return image
  }
}

private struct FrancePosterView: View {
  let departments: [MapPrefecture]
  let visitedCodes: Set<String>
  let visitedColor: Color
  let size: CGSize

  private var isTall: Bool { size.height > 600 }

  private var departmentCountText: String {
    "\(visitedCodes.count) / 101 \(L10n.text("france_share.departments"))"
  }

  private var percentageText: String {
    let percentage = (Double(visitedCodes.count) / 101 * 100)
      .formatted(.number.precision(.fractionLength(1)))
    return L10n.text("france_share.percentage_prefix") + percentage + "%"
  }

  var body: some View {
    VStack(spacing: isTall ? 44 : 20) {
      header
      posterMap
        .frame(height: isTall ? 540 : 330)
      stats
    }
    .padding(.horizontal, 38)
    .padding(.vertical, isTall ? 76 : 30)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(red: 0.95, green: 0.97, blue: 0.95))
    .foregroundStyle(Color(red: 0.10, green: 0.19, blue: 0.20))
  }

  private var header: some View {
    VStack(spacing: 5) {
      Text(L10n.text("france_share.poster_title"))
        .font(.system(size: isTall ? 34 : 27, weight: .bold, design: .rounded))
      Text("COLORVIA")
        .font(.system(size: 10, weight: .semibold, design: .rounded))
        .tracking(3)
        .foregroundStyle(Color(red: 0.22, green: 0.42, blue: 0.43))
    }
  }

  private var stats: some View {
    VStack(spacing: 7) {
      Text(departmentCountText)
        .font(.system(size: 23, weight: .semibold, design: .rounded))
      Text(percentageText)
        .font(.system(size: 15, weight: .medium, design: .rounded))
        .foregroundStyle(Color(red: 0.28, green: 0.36, blue: 0.37))
    }
  }

  private var posterMap: some View {
    GeometryReader { proxy in
      Canvas { context, canvasSize in
        let side = min(canvasSize.width, canvasSize.height)
        let rect = CGRect(
          x: (canvasSize.width - side) / 2,
          y: (canvasSize.height - side) / 2,
          width: side,
          height: side
        )
        for department in departments {
          let path = Path { path in
            for polygon in department.polygons where polygon.count > 2 {
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
              visitedCodes.contains(department.code)
                ? visitedColor : Color(red: 0.83, green: 0.87, blue: 0.83)
            )
          )
          context.stroke(
            path,
            with: .color(Color.white.opacity(0.9)),
            lineWidth: 0.7
          )
        }
      }
      .background(Color(red: 0.83, green: 0.92, blue: 0.92))
      .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
  }
}
