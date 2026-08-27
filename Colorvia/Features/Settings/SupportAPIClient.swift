import Foundation

enum SupportAPIConfiguration {
  static let endpoint = URL(
    string: "https://api.tmkch.io/api/support"
  )!
  static let privacyPolicy = AppConfiguration.current.privacyPolicyURL
  static let termsOfService = AppConfiguration.current.termsURL
  static let source = "colorvia-ios"
  static let commercialTransactions = URL(
    string: "https://colorvia.tmkch.io/commercial-transactions"
  )!
  /// Where to send someone when the in-app form cannot reach the API.
  static let supportPage = AppConfiguration.current.supportURL
}

/// The four kinds of enquiry the shared support API accepts. Kept in step with
/// `supportCategories` in the API and with the categories offered on
/// tmkch.io/support, so a message sent from the app and one sent from the web
/// arrive filed the same way.
enum SupportCategory: String, CaseIterable, Codable, Identifiable, Sendable {
  case question
  case bug
  case feature
  case other

  var id: String { rawValue }

  var localizedName: String {
    switch self {
    case .question: L10n.text("contact.category.question")
    case .bug: L10n.text("contact.category.bug")
    case .feature: L10n.text("contact.category.feature")
    case .other: L10n.text("contact.category.other")
    }
  }

  var iconName: String {
    switch self {
    case .question: "questionmark.circle"
    case .bug: "ladybug"
    case .feature: "lightbulb"
    case .other: "ellipsis.circle"
    }
  }

  /// Whether choosing this category is already asking for an answer.
  ///
  /// A question is a request for a reply by definition, so offering a "would
  /// you like a reply?" switch beside it asks something nobody can sensibly
  /// answer no to: these categories skip the switch and need an address
  /// outright. A bug report, an idea or a passing remark are all things people
  /// send without wanting anything back, and those are the ones worth not
  /// asking an email address for.
  var impliesReply: Bool {
    switch self {
    case .question: true
    case .bug, .feature, .other: false
    }
  }
}

struct SupportRequest: Codable, Sendable {
  let requestId: UUID
  let clientId: UUID
  let source: String
  let app: String
  let category: SupportCategory
  let name: String
  let email: String
  let message: String
  let appVersion: String
  let buildNumber: String
  let osVersion: String
  let locale: String
  let submittedAt: Date
  let website: String
}

struct SupportResponse: Decodable, Equatable, Sendable {
  let requestId: UUID

  private enum CodingKeys: String, CodingKey {
    case requestId
    case receiptId
    case id
    case data
  }

  private struct NestedResponse: Decodable {
    let requestId: UUID?
    let receiptId: UUID?
    let id: UUID?
  }

  init(requestId: UUID) {
    self.requestId = requestId
  }

  init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    if let requestId = try container.decodeIfPresent(UUID.self, forKey: .requestId) {
      self.requestId = requestId
    } else if let receiptId = try container.decodeIfPresent(UUID.self, forKey: .receiptId) {
      self.requestId = receiptId
    } else if let id = try container.decodeIfPresent(UUID.self, forKey: .id) {
      self.requestId = id
    } else if let data = try container.decodeIfPresent(NestedResponse.self, forKey: .data),
      let nestedID = data.requestId ?? data.receiptId ?? data.id
    {
      self.requestId = nestedID
    } else {
      throw DecodingError.keyNotFound(
        CodingKeys.requestId,
        .init(codingPath: decoder.codingPath, debugDescription: "A request ID is required.")
      )
    }
  }
}

enum SupportAPIError: Error, Equatable {
  case invalidRequest
  case rateLimited
  case deliveryFailed
  case serverError
  case networkUnavailable
  case timedOut
  case invalidResponse
}

struct SupportAPIClient: Sendable {
  private let session: URLSession

  init(session: URLSession = .shared) {
    self.session = session
  }

  func submit(_ request: SupportRequest) async throws -> SupportResponse {
    var urlRequest = URLRequest(url: SupportAPIConfiguration.endpoint)
    urlRequest.httpMethod = "POST"
    urlRequest.timeoutInterval = 20
    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
    urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")

    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    do {
      urlRequest.httpBody = try encoder.encode(request)
    } catch {
      throw SupportAPIError.invalidRequest
    }

    do {
      let (data, response) = try await session.data(for: urlRequest)
      guard let response = response as? HTTPURLResponse else {
        throw SupportAPIError.invalidResponse
      }
      guard (200..<300).contains(response.statusCode) else {
        throw Self.apiError(statusCode: response.statusCode, data: data)
      }

      if let decoded = try? JSONDecoder().decode(SupportResponse.self, from: data) {
        return decoded
      }
      if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
        object["ok"] as? Bool == true || object["success"] as? Bool == true
      {
        return SupportResponse(requestId: request.requestId)
      }
      throw SupportAPIError.invalidResponse
    } catch is CancellationError {
      throw CancellationError()
    } catch let error as SupportAPIError {
      throw error
    } catch let error as URLError {
      switch error.code {
      case .timedOut:
        throw SupportAPIError.timedOut
      default:
        throw SupportAPIError.networkUnavailable
      }
    } catch {
      throw SupportAPIError.networkUnavailable
    }
  }

  private struct ErrorEnvelope: Decodable {
    let code: String?
  }

  private static func apiError(statusCode: Int, data: Data) -> SupportAPIError {
    let code = (try? JSONDecoder().decode(ErrorEnvelope.self, from: data).code)?
      .lowercased()
      .replacingOccurrences(of: "-", with: "_")

    switch code {
    case "invalid_request", "validation_error":
      return .invalidRequest
    case "rate_limited", "too_many_requests":
      return .rateLimited
    case "delivery_failed", "email_delivery_failed":
      return .deliveryFailed
    default:
      switch statusCode {
      case 400, 422: return .invalidRequest
      case 429: return .rateLimited
      case 502: return .deliveryFailed
      case 500...599: return .serverError
      default: return .invalidResponse
      }
    }
  }
}
