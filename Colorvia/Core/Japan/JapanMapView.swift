import SwiftUI

struct JapanMapView: View {
  let prefectures: [MapPrefecture]
  let visitedCodes: Set<String>
  var compact = false
  var visitedColor = ColorviaTheme.accent
  var highlightedCode: String?
  var accessibilityLabel = L10n.text("japan_map.accessibility_label")

  @State private var scale: CGFloat = 1
  @State private var lastScale: CGFloat = 1
  @State private var offset: CGSize = .zero
  @State private var lastOffset: CGSize = .zero

  var body: some View {
    GeometryReader { proxy in
      ZStack(alignment: .topLeading) {
        ColorviaTheme.sea

        Canvas { context, size in
          let mapRect = fittedMapRect(in: size)
          for prefecture in prefectures {
            let path = path(for: prefecture, in: mapRect)
            let fill =
              visitedCodes.contains(prefecture.code)
              ? visitedColor : ColorviaTheme.land
            context.fill(path, with: .color(fill))
            context.stroke(
              path,
              with: .color(
                prefecture.code == highlightedCode
                  ? ColorviaTheme.ink : ColorviaTheme.border.opacity(0.78)
              ),
              lineWidth: prefecture.code == highlightedCode ? 2 : (compact ? 0.45 : 0.7)
            )
          }
        }
        .scaleEffect(scale)
        .offset(offset)

        if !compact {
          mapControls(in: proxy.size)
            .padding(12)
        }
      }
      .contentShape(Rectangle())
      .clipShape(RoundedRectangle(cornerRadius: compact ? 18 : 28, style: .continuous))
      .gesture(mapGesture(in: proxy.size))
      .onTapGesture(count: 2) {
        if scale > 1 {
          resetMap()
        } else {
          setScale(2, in: proxy.size)
        }
      }
      .accessibilityLabel(accessibilityLabel)
      .accessibilityValue(L10n.visitedPrefectureSummary(visitedCodes.count))
    }
  }

  private func mapControls(in size: CGSize) -> some View {
    HStack(spacing: 0) {
      mapControlButton(
        icon: "minus",
        label: L10n.text("map.zoom_out"),
        disabled: scale <= 1
      ) {
        setScale(scale - 0.5, in: size)
      }
      Divider().frame(height: 20)
      mapControlButton(
        icon: "plus",
        label: L10n.text("map.zoom_in"),
        disabled: scale >= 4
      ) {
        setScale(scale + 0.5, in: size)
      }
      Divider().frame(height: 20)
      mapControlButton(
        icon: "arrow.counterclockwise",
        label: L10n.text("map.reset"),
        disabled: scale == 1 && offset == .zero
      ) {
        resetMap()
      }
    }
    .padding(.horizontal, 3)
    .background(.ultraThinMaterial, in: Capsule())
    .overlay(Capsule().stroke(.white.opacity(0.65), lineWidth: 0.5))
    .shadow(color: ColorviaTheme.ink.opacity(0.1), radius: 8, y: 3)
  }

  private func mapControlButton(
    icon: String,
    label: String,
    disabled: Bool,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      Image(systemName: icon)
        .font(.system(size: 13, weight: .semibold))
        .frame(width: 37, height: 36)
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .foregroundStyle(disabled ? ColorviaTheme.secondaryInk.opacity(0.35) : ColorviaTheme.ink)
    .disabled(disabled)
    .accessibilityLabel(label)
  }

  private func mapGesture(in size: CGSize) -> some Gesture {
    MagnifyGesture()
      .onChanged { value in
        scale = min(max(lastScale * value.magnification, 1), 4)
        offset = clamped(offset, in: size, at: scale)
      }
      .onEnded { _ in
        lastScale = scale
        offset = clamped(offset, in: size, at: scale)
        lastOffset = offset
      }
      .simultaneously(
        with:
          DragGesture(minimumDistance: 3)
          .onChanged { value in
            guard scale > 1 else { return }
            offset = clamped(
              CGSize(
                width: lastOffset.width + value.translation.width,
                height: lastOffset.height + value.translation.height
              ),
              in: size,
              at: scale
            )
          }
          .onEnded { _ in
            offset = clamped(offset, in: size, at: scale)
            lastOffset = offset
          }
      )
  }

  private func setScale(_ proposedScale: CGFloat, in size: CGSize) {
    withAnimation(.easeOut(duration: 0.22)) {
      scale = min(max(proposedScale, 1), 4)
      lastScale = scale
      offset = clamped(offset, in: size, at: scale)
      lastOffset = offset
    }
  }

  private func resetMap() {
    withAnimation(.easeOut(duration: 0.28)) {
      scale = 1
      lastScale = 1
      offset = .zero
      lastOffset = .zero
    }
  }

  private func clamped(_ proposedOffset: CGSize, in size: CGSize, at scale: CGFloat) -> CGSize {
    guard scale > 1 else { return .zero }
    return CGSize(
      width: min(
        max(proposedOffset.width, -size.width * (scale - 1) / 2), size.width * (scale - 1) / 2),
      height: min(
        max(proposedOffset.height, -size.height * (scale - 1) / 2), size.height * (scale - 1) / 2)
    )
  }

  private func fittedMapRect(in size: CGSize) -> CGRect {
    let side = min(size.width * 0.92, size.height * 0.92)
    return CGRect(
      x: (size.width - side) / 2,
      y: (size.height - side) / 2,
      width: side,
      height: side
    )
  }

  private func path(for prefecture: MapPrefecture, in rect: CGRect) -> Path {
    Path { path in
      for polygon in prefecture.polygons where polygon.count > 2 {
        let first = polygon[0]
        path.move(
          to: CGPoint(x: rect.minX + first.x * rect.width, y: rect.minY + first.y * rect.height)
        )
        for point in polygon.dropFirst() {
          path.addLine(
            to: CGPoint(x: rect.minX + point.x * rect.width, y: rect.minY + point.y * rect.height)
          )
        }
        path.closeSubpath()
      }
    }
  }
}
