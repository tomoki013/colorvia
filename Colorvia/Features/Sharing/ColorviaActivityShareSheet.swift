import LinkPresentation
import SwiftUI
import UIKit

struct ColorviaSharePayload: Identifiable {
  let id = UUID()
  let image: UIImage
  let message: String
}

struct ColorviaActivityShareSheet: UIViewControllerRepresentable {
  let payload: ColorviaSharePayload

  func makeUIViewController(context: Context) -> UIActivityViewController {
    let description = ColorviaShareDescription(
      message: payload.message,
      image: payload.image
    )
    return UIActivityViewController(
      activityItems: [payload.image, description],
      applicationActivities: nil
    )
  }

  func updateUIViewController(
    _ uiViewController: UIActivityViewController,
    context: Context
  ) {}
}

private final class ColorviaShareDescription: NSObject, UIActivityItemSource {
  private let message: String
  private let image: UIImage

  init(message: String, image: UIImage) {
    self.message = message
    self.image = image
  }

  func activityViewControllerPlaceholderItem(
    _ activityViewController: UIActivityViewController
  ) -> Any {
    message as NSString
  }

  func activityViewController(
    _ activityViewController: UIActivityViewController,
    itemForActivityType activityType: UIActivity.ActivityType?
  ) -> Any? {
    "\(message)\n\(ColorviaShareLinks.universalLinkURL.absoluteString)" as NSString
  }

  func activityViewController(
    _ activityViewController: UIActivityViewController,
    subjectForActivityType activityType: UIActivity.ActivityType?
  ) -> String {
    "Colorvia"
  }

  func activityViewControllerLinkMetadata(
    _ activityViewController: UIActivityViewController
  ) -> LPLinkMetadata? {
    let metadata = LPLinkMetadata()
    metadata.title = "Colorvia"
    metadata.originalURL = ColorviaShareLinks.universalLinkURL
    metadata.url = ColorviaShareLinks.universalLinkURL
    metadata.imageProvider = NSItemProvider(object: image)
    return metadata
  }
}

enum ColorviaShareLinks {
  static let universalLinkURL = URL(string: "https://colorvia.tmkch.io/open")!
}
