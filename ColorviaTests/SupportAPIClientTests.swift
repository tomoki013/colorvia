import Foundation
import Testing

@testable import Colorvia

struct SupportAPIClientTests {
  @Test func supportPostCarriesTheConfiguredClientKey() throws {
    let client = SupportAPIClient(clientKey: "configured-client-key")

    let request = try client.urlRequest(for: Self.sampleRequest)

    #expect(
      request.value(forHTTPHeaderField: "X-Support-Client") == "configured-client-key"
    )
    #expect(SupportAPIConfiguration.clientHeader == "X-Support-Client")
  }

  /// A build with no key configured sends no header at all, rather than an
  /// empty one: the API reads a present-but-wrong value as a refusal.
  @Test func supportPostOmitsTheClientHeaderWhenNothingIsConfigured() throws {
    let client = SupportAPIClient(clientKey: nil)

    let request = try client.urlRequest(for: Self.sampleRequest)

    #expect(request.value(forHTTPHeaderField: "X-Support-Client") == nil)
  }

  /// The versioned path, which Remeet also uses. The API still answers the
  /// unversioned `/api/support` it was written against, so this is about not
  /// being the only caller left on an alias.
  @Test func supportPostGoesToTheVersionedEndpoint() throws {
    let request = try SupportAPIClient(clientKey: nil).urlRequest(for: Self.sampleRequest)

    #expect(request.url == URL(string: "https://api.tmkch.io/api/v1/support"))
    #expect(request.httpMethod == "POST")
  }

  /// A blank build setting is the same as no build setting: an empty header
  /// would read as a wrong key once the API enforces one, where a missing
  /// header is what a build from before this change sends.
  @Test func supportPostOmitsTheClientHeaderWhenTheKeyIsBlank() throws {
    for blank in ["", " ", "\n"] {
      let request = try SupportAPIClient(clientKey: blank)
        .urlRequest(for: Self.sampleRequest)
      #expect(request.value(forHTTPHeaderField: "X-Support-Client") == nil)
    }
  }

  /// The API validates the body strictly, so the key travels in a header and
  /// leaves the submitted fields exactly as they were.
  @Test func clientKeyDoesNotChangeTheRequestBody() throws {
    let submission = Self.sampleRequest
    let withKey = try SupportAPIClient(clientKey: "configured-client-key")
      .urlRequest(for: submission)
    let withoutKey = try SupportAPIClient(clientKey: nil)
      .urlRequest(for: submission)

    let keyed = try Self.body(of: withKey)
    let unkeyed = try Self.body(of: withoutKey)

    #expect(keyed == unkeyed)
    #expect(
      Set(keyed.allKeys.compactMap { $0 as? String }) == [
        "requestId", "clientId", "source", "app", "category", "name", "email",
        "message", "appVersion", "buildNumber", "osVersion", "locale",
        "submittedAt", "website",
      ]
    )
  }

  @Test func configuredClientKeyComesFromTheBuildSetting() {
    #expect(Self.configuration(supportClientKey: "abc123").supportClientKey == "abc123")
    #expect(Self.configuration(supportClientKey: nil).supportClientKey == nil)
    #expect(Self.configuration(supportClientKey: "  ").supportClientKey == nil)
    // A build that never set the setting leaves the substitution unexpanded.
    #expect(
      Self.configuration(supportClientKey: "$(SUPPORT_CLIENT_KEY)").supportClientKey == nil
    )
  }

  /// The encoded body as a dictionary. `JSONEncoder` does not promise a stable
  /// key order between calls, so the two requests are compared by their fields
  /// rather than byte for byte.
  private static func body(of request: URLRequest) throws -> NSDictionary {
    let data = try #require(request.httpBody)
    return try #require(try JSONSerialization.jsonObject(with: data) as? NSDictionary)
  }

  private static func configuration(supportClientKey: String?) -> AppConfiguration {
    AppConfiguration(
      adsEnabled: false,
      cloudSyncEnabled: false,
      admobAppID: nil,
      bannerAdUnitID: nil,
      privacyPolicyURL: URL(string: "https://colorvia.tmkch.io/privacy")!,
      termsURL: URL(string: "https://colorvia.tmkch.io/terms")!,
      supportURL: URL(string: "https://tmkch.io/support?app=colorvia")!,
      marketingURL: URL(string: "https://colorvia.tmkch.io")!,
      supportClientKey: supportClientKey
    )
  }

  private static var sampleRequest: SupportRequest {
    SupportRequest(
      requestId: UUID(),
      clientId: UUID(),
      source: SupportAPIConfiguration.source,
      app: "colorvia",
      category: .bug,
      name: "",
      email: "",
      message: "The map did not redraw after I marked a prefecture.",
      appVersion: "1.0.1",
      buildNumber: "1",
      osVersion: "iOS 18.0",
      locale: "ja_JP",
      submittedAt: Date(timeIntervalSince1970: 1_700_000_000),
      website: ""
    )
  }
}
