import SwiftUI
import UIKit

struct ContactSupportView: View {
  @State private var email = ""
  @State private var message = ""
  @State private var submissionState: SubmissionState = .idle
  @State private var submissionTask: Task<Void, Never>?

  private enum SubmissionState: Equatable {
    case idle
    case submitting
    case success
    case failure(SupportAPIError)
  }

  var body: some View {
    Form {
      Section {
        TextField(L10n.text("contact.email_placeholder"), text: $email)
          .textContentType(.emailAddress)
          .keyboardType(.emailAddress)
          .textInputAutocapitalization(.never)
          .autocorrectionDisabled()

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
          .onChange(of: message) { _, value in
            if value.count > 5_000 {
              message = String(value.prefix(5_000))
            }
          }
      } header: {
        Text(L10n.text("contact.form_title"))
      } footer: {
        Text(L10n.text("contact.footer"))
      }

      if case .failure(let error) = submissionState {
        Section {
          Label(errorMessage(for: error), systemImage: "exclamationmark.triangle.fill")
            .font(.subheadline)
            .foregroundStyle(.red)
        }
      }

      Section {
        Button {
          submissionTask?.cancel()
          submissionTask = Task {
            await submit()
          }
        } label: {
          HStack(spacing: 10) {
            if submissionState == .submitting {
              ProgressView()
            } else {
              Image(systemName: "paperplane")
            }
            Text(L10n.text("contact.send"))
          }
          .frame(maxWidth: .infinity)
        }
        .disabled(!canSubmit)
      }
    }
    .scrollContentBackground(.hidden)
    .background(ColorviaTheme.background)
    .navigationTitle(L10n.text("settings.contact"))
    .navigationBarTitleDisplayMode(.inline)
    .alert(
      L10n.text("contact.sent_title"),
      isPresented: Binding(
        get: { submissionState == .success },
        set: { if !$0 { submissionState = .idle } }
      )
    ) {
      Button(L10n.text("common.close"), role: .cancel) {
        email = ""
        message = ""
      }
    } message: {
      Text(L10n.text("contact.sent_body"))
    }
    .onDisappear {
      submissionTask?.cancel()
      submissionTask = nil
    }
  }

  private var canSubmit: Bool {
    submissionState != .submitting
      && isEmailValid
      && (10...5_000).contains(message.count)
  }

  private var isEmailValid: Bool {
    let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
    let parts = trimmed.split(separator: "@", omittingEmptySubsequences: false)
    guard parts.count == 2, !parts[0].isEmpty, parts[0].count <= 64 else { return false }
    let domain = parts[1]
    return trimmed.count <= 254
      && domain.contains(".")
      && !domain.hasPrefix(".")
      && !domain.hasSuffix(".")
      && !trimmed.contains(where: \.isWhitespace)
  }

  @MainActor
  private func submit() async {
    guard canSubmit else { return }
    submissionState = .submitting

    let requestID = UUID()
    let request = SupportRequest(
      requestId: requestID,
      clientId: supportClientID,
      source: "colorvia-ios",
      app: "colorvia",
      category: "question",
      name: "",
      email: email.trimmingCharacters(in: .whitespacesAndNewlines),
      message: message.trimmingCharacters(in: .whitespacesAndNewlines),
      appVersion: Bundle.main.object(
        forInfoDictionaryKey: "CFBundleShortVersionString"
      ) as? String ?? "1.0.0",
      buildNumber: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1",
      osVersion: "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)",
      locale: Locale.current.identifier,
      submittedAt: .now,
      website: ""
    )

    do {
      _ = try await SupportAPIClient().submit(request)
      guard !Task.isCancelled else { return }
      submissionState = .success
    } catch is CancellationError {
      submissionState = .idle
    } catch let error as SupportAPIError {
      submissionState = .failure(error)
    } catch {
      submissionState = .failure(.networkUnavailable)
    }
  }

  private var supportClientID: UUID {
    let key = "supportClientId"
    if let value = UserDefaults.standard.string(forKey: key),
      let id = UUID(uuidString: value)
    {
      return id
    }
    let id = UUID()
    UserDefaults.standard.set(id.uuidString, forKey: key)
    return id
  }

  private func errorMessage(for error: SupportAPIError) -> String {
    let isJapanese = (Bundle.main.preferredLocalizations.first ?? "en").hasPrefix("ja")
    switch error {
    case .invalidRequest:
      return isJapanese
        ? "入力内容を確認して、もう一度お試しください。"
        : "Check the form and try again."
    case .rateLimited:
      return isJapanese
        ? "送信回数が多すぎます。しばらくしてからお試しください。"
        : "Too many requests. Please try again later."
    case .deliveryFailed, .serverError, .invalidResponse:
      return isJapanese
        ? "送信できませんでした。しばらくしてからお試しください。"
        : "Your message could not be sent. Please try again later."
    case .networkUnavailable:
      return isJapanese
        ? "通信環境を確認して、もう一度お試しください。"
        : "Check your connection and try again."
    case .timedOut:
      return isJapanese
        ? "通信がタイムアウトしました。もう一度お試しください。"
        : "The request timed out. Please try again."
    }
  }
}
