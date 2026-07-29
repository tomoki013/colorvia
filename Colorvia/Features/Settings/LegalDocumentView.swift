import SwiftUI
import WebKit

/// The website is the canonical copy. The supplied sections are bundled with
/// the app and remain readable when the endpoint cannot be reached.
struct LegalDocumentView: View {
  let title: String
  let url: URL
  let sections: [(title: String, body: String)]

  @State private var availability: Availability = .checking

  private enum Availability {
    case checking
    case online
    case offline
  }

  var body: some View {
    ZStack {
      ColorviaTheme.background.ignoresSafeArea()

      switch availability {
      case .checking:
        VStack(spacing: 12) {
          ProgressView()
          Text(
            localizedLegalText(
              english: "Checking for the latest version…",
              japanese: "最新版を確認しています…"
            )
          )
            .font(.caption)
            .foregroundStyle(ColorviaTheme.secondaryInk)
        }
      case .online:
        LegalWebView(url: url) {
          availability = .offline
        }
        .ignoresSafeArea(edges: .bottom)
      case .offline:
        OfflineLegalDocument(sections: sections)
      }
    }
    .navigationTitle(title)
    .navigationBarTitleDisplayMode(.inline)
    .task(id: url) {
      await checkAvailability()
    }
  }

  private func checkAvailability() async {
    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    request.timeoutInterval = 5
    request.cachePolicy = .reloadIgnoringLocalCacheData

    do {
      let (_, response) = try await URLSession.shared.data(for: request)
      guard !Task.isCancelled else { return }
      if let response = response as? HTTPURLResponse,
        (200..<400).contains(response.statusCode)
      {
        availability = .online
      } else {
        availability = .offline
      }
    } catch is CancellationError {
      return
    } catch {
      availability = .offline
    }
  }
}

private struct LegalWebView: UIViewRepresentable {
  let url: URL
  let onLoadFailure: @MainActor () -> Void

  private static let hideSiteChrome = """
    var style = document.createElement('style');
    style.textContent = '.mock-header,.mock-footer{display:none !important;}';
    document.documentElement.appendChild(style);
    """

  func makeCoordinator() -> Coordinator {
    Coordinator(onLoadFailure: onLoadFailure)
  }

  func makeUIView(context: Context) -> WKWebView {
    let configuration = WKWebViewConfiguration()
    configuration.userContentController.addUserScript(
      WKUserScript(
        source: Self.hideSiteChrome,
        injectionTime: .atDocumentStart,
        forMainFrameOnly: true
      )
    )

    let webView = WKWebView(frame: .zero, configuration: configuration)
    webView.navigationDelegate = context.coordinator
    webView.load(URLRequest(url: url))
    return webView
  }

  func updateUIView(_ webView: WKWebView, context: Context) {
    guard webView.url != url else { return }
    webView.load(URLRequest(url: url))
  }

  final class Coordinator: NSObject, WKNavigationDelegate {
    let onLoadFailure: @MainActor () -> Void

    init(onLoadFailure: @escaping @MainActor () -> Void) {
      self.onLoadFailure = onLoadFailure
    }

    func webView(
      _ webView: WKWebView,
      didFail navigation: WKNavigation?,
      withError error: any Error
    ) {
      Task { @MainActor in onLoadFailure() }
    }

    func webView(
      _ webView: WKWebView,
      didFailProvisionalNavigation navigation: WKNavigation?,
      withError error: any Error
    ) {
      Task { @MainActor in onLoadFailure() }
    }
  }
}

private struct OfflineLegalDocument: View {
  let sections: [(title: String, body: String)]

  var body: some View {
    ScrollView(showsIndicators: false) {
      LazyVStack(alignment: .leading, spacing: 16) {
        Label(
          localizedLegalText(
            english: "You are offline. The copy bundled with the app is shown temporarily.",
            japanese: "オフラインのため、アプリに同梱した内容を一時的に表示しています。"
          ),
          systemImage: "wifi.slash"
        )
          .font(.caption)
          .foregroundStyle(ColorviaTheme.secondaryInk)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(14)
          .background(ColorviaTheme.card, in: RoundedRectangle(cornerRadius: 16))

        ForEach(Array(sections.enumerated()), id: \.offset) { _, section in
          VStack(alignment: .leading, spacing: 9) {
            Text(section.title)
              .font(.headline)
              .foregroundStyle(ColorviaTheme.ink)
            Text(section.body)
              .font(.body)
              .foregroundStyle(ColorviaTheme.secondaryInk)
              .fixedSize(horizontal: false, vertical: true)
              .textSelection(.enabled)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(18)
          .background(ColorviaTheme.card, in: RoundedRectangle(cornerRadius: 20))
        }
      }
      .padding(20)
    }
  }
}

private func localizedLegalText(english: String, japanese: String) -> String {
  let language = Bundle.main.preferredLocalizations.first ?? "en"
  return language.hasPrefix("ja") ? japanese : english
}
