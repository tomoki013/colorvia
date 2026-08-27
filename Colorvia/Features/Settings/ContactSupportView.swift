import SwiftUI
import UIKit

/// The in-app half of the shared support form at tmkch.io/support. Same
/// categories, same optional name, and the same rule about email addresses: one
/// is asked for only when there is a reply to send.
struct ContactSupportView: View {
  @Environment(\.openURL) private var openURL
  @State private var category: SupportCategory = .question
  @State private var name = ""
  @State private var email = ""
  @State private var message = ""
  @State private var wantsReply = false
  @State private var submissionState: SubmissionState = .idle
  @State private var submissionTask: Task<Void, Never>?
  @FocusState private var focusedField: Field?

  private enum Field {
    case name
    case email
    case message
  }

  private enum SubmissionState: Equatable {
    case idle
    case submitting
    case success(SupportResponse)
    case failure(SupportAPIError)
  }

  var body: some View {
    Group {
      if case .success(let response) = submissionState {
        successView(response)
      } else {
        form
      }
    }
    .background(ColorviaTheme.background)
    .navigationTitle(L10n.text("settings.contact"))
    .navigationBarTitleDisplayMode(.inline)
    .onDisappear {
      submissionTask?.cancel()
      submissionTask = nil
    }
  }

  private var form: some View {
    Form {
      Section {
        Text(L10n.text("contact.lead"))
          .font(.subheadline)
          .foregroundStyle(ColorviaTheme.secondaryInk)
          .fixedSize(horizontal: false, vertical: true)
          .listRowBackground(Color.clear)
          .listRowSeparator(.hidden)
      }

      Section {
        Picker(selection: $category) {
          ForEach(SupportCategory.allCases) { category in
            Label(category.localizedName, systemImage: category.iconName)
              .tag(category)
          }
        } label: {
          Label(L10n.text("contact.category"), systemImage: "tray.full")
        }
        .pickerStyle(.menu)
      }

      Section {
        TextField(L10n.text("contact.name_placeholder"), text: $name)
          .textContentType(.name)
          .focused($focusedField, equals: .name)
          .submitLabel(.next)
          .onSubmit { focusedField = .message }
          .onChange(of: name) { _, value in
            if value.count > 100 { name = String(value.prefix(100)) }
          }
      } header: {
        fieldHeader(L10n.text("contact.name"), isRequired: false)
      }

      Section {
        TextEditor(text: $message)
          .frame(minHeight: 150)
          .focused($focusedField, equals: .message)
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
            if value.count > 5_000 { message = String(value.prefix(5_000)) }
          }
        HStack {
          Spacer()
          Text(verbatim: "\(message.count) / 5000")
            .font(.caption.monospacedDigit())
            .foregroundStyle(ColorviaTheme.secondaryInk)
        }
        .listRowSeparator(.hidden)
      } header: {
        fieldHeader(L10n.text("contact.message"), isRequired: true)
      }

      // The reply question comes after the message rather than before it:
      // whether you want an answer is a decision about what you have just
      // written, and asking for an address first reads as a toll gate.
      Section {
        if category.impliesReply {
          Text(L10n.text("contact.reply_required_note"))
            .font(.footnote)
            .foregroundStyle(ColorviaTheme.secondaryInk)
            .fixedSize(horizontal: false, vertical: true)
        } else {
          Toggle(L10n.text("contact.reply_requested"), isOn: $wantsReply)
          Text(L10n.text("contact.reply_note"))
            .font(.footnote)
            .foregroundStyle(ColorviaTheme.secondaryInk)
            .fixedSize(horizontal: false, vertical: true)
        }
      }

      if requiresEmail {
        Section {
          TextField(L10n.text("contact.email_hint"), text: $email)
            .textContentType(.emailAddress)
            .keyboardType(.emailAddress)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .focused($focusedField, equals: .email)
            .submitLabel(.done)
            .onSubmit { focusedField = nil }
        } header: {
          fieldHeader(L10n.text("contact.email_placeholder"), isRequired: true)
        }
      }

      if case .failure(let error) = submissionState {
        Section {
          VStack(alignment: .leading, spacing: 8) {
            Label(L10n.text("contact.error_title"), systemImage: "exclamationmark.triangle.fill")
              .font(.subheadline.weight(.semibold))
              .foregroundStyle(.red)
            Text(errorMessage(for: error))
              .font(.footnote)
              .foregroundStyle(ColorviaTheme.secondaryInk)
              .fixedSize(horizontal: false, vertical: true)
            Button {
              openURL(localizedLegalURL(SupportAPIConfiguration.supportPage))
            } label: {
              Label(L10n.text("contact.web_fallback"), systemImage: "safari")
                .font(.footnote.weight(.semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(ColorviaTheme.accentDeep)
          }
        }
      }

      Section {
        Button {
          focusedField = nil
          submissionTask?.cancel()
          submissionTask = Task { await submit() }
        } label: {
          HStack(spacing: 10) {
            if submissionState == .submitting {
              ProgressView()
            } else {
              Image(systemName: "paperplane")
            }
            Text(
              submissionState == .submitting
                ? L10n.text("contact.submitting") : L10n.text("contact.send")
            )
          }
          .frame(maxWidth: .infinity)
        }
        .disabled(!canSubmit)
      } footer: {
        VStack(alignment: .leading, spacing: 10) {
          Text(L10n.text("contact.footer"))
          Button {
            openURL(localizedLegalURL(SupportAPIConfiguration.privacyPolicy))
          } label: {
            HStack(spacing: 4) {
              Text(L10n.text("contact.privacy_note"))
              Image(systemName: "arrow.up.right")
                .font(.caption2)
            }
            .foregroundStyle(ColorviaTheme.accentDeep)
            .multilineTextAlignment(.leading)
          }
          .buttonStyle(.plain)
        }
        .fixedSize(horizontal: false, vertical: true)
      }
    }
    .scrollContentBackground(.hidden)
    .scrollDismissesKeyboard(.interactively)
  }

  private func fieldHeader(_ title: String, isRequired: Bool) -> some View {
    HStack(spacing: 6) {
      Text(title)
      Text(isRequired ? L10n.text("contact.required") : L10n.text("contact.optional"))
        .font(.caption2.weight(.bold))
        .foregroundStyle(isRequired ? Color.red : ColorviaTheme.secondaryInk)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
          (isRequired ? Color.red.opacity(0.12) : ColorviaTheme.secondaryInk.opacity(0.12)),
          in: RoundedRectangle(cornerRadius: 5, style: .continuous)
        )
    }
  }

  private func successView(_ response: SupportResponse) -> some View {
    ScrollView {
      VStack(spacing: 18) {
        Image(systemName: "checkmark")
          .font(.system(size: 22, weight: .bold))
          .foregroundStyle(ColorviaTheme.background)
          .frame(width: 62, height: 62)
          .background(ColorviaTheme.accentDeep, in: Circle())
        Text(L10n.text("contact.sent_title"))
          .font(.title3.weight(.semibold))
          .foregroundStyle(ColorviaTheme.ink)
        Text(
          requiresEmail
            ? L10n.text("contact.sent_body") : L10n.text("contact.sent_body_no_reply")
        )
        .font(.subheadline)
        .foregroundStyle(ColorviaTheme.secondaryInk)
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)

        VStack(spacing: 6) {
          Text(L10n.text("contact.receipt"))
            .font(.caption)
            .foregroundStyle(ColorviaTheme.secondaryInk)
          Text(response.requestId.uuidString)
            .font(.footnote.monospaced())
            .foregroundStyle(ColorviaTheme.ink)
            .multilineTextAlignment(.center)
            .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(ColorviaTheme.card, in: RoundedRectangle(cornerRadius: 16))

        Button {
          startNewEnquiry()
        } label: {
          Text(L10n.text("contact.new_request"))
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(ColorviaTheme.background)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(ColorviaTheme.accentDeep, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
      }
      .padding(24)
    }
  }

  /// Two ways an address becomes necessary: the category is already a question,
  /// or a reply was asked for. There is no third state where it is merely
  /// optional — either it is needed to answer, or it is not wanted at all.
  private var requiresEmail: Bool { category.impliesReply || wantsReply }

  /// The address as it actually leaves the device: nothing at all unless a
  /// reply was asked for. Anything typed before the switch was turned off stays
  /// in the field, so toggling back does not lose it, but it is never sent.
  private var outgoingEmail: String {
    guard requiresEmail else { return "" }
    return email.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private var canSubmit: Bool {
    submissionState != .submitting
      && (!requiresEmail || isEmailValid)
      && name.count <= 100
      && (10...5_000).contains(message.trimmingCharacters(in: .whitespacesAndNewlines).count)
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

  private func startNewEnquiry() {
    category = .question
    name = ""
    email = ""
    message = ""
    wantsReply = false
    submissionState = .idle
  }

  @MainActor
  private func submit() async {
    guard canSubmit else { return }
    submissionState = .submitting

    let request = SupportRequest(
      requestId: UUID(),
      clientId: supportClientID,
      source: SupportAPIConfiguration.source,
      app: "colorvia",
      category: category,
      name: name.trimmingCharacters(in: .whitespacesAndNewlines),
      email: outgoingEmail,
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
      let response = try await SupportAPIClient().submit(request)
      guard !Task.isCancelled else { return }
      submissionState = .success(response)
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
    switch error {
    case .invalidRequest:
      return localizedLegalText(
        english: "Check the form and try again.",
        japanese: "入力内容を確認して、もう一度お試しください。"
      )
    case .rateLimited:
      return localizedLegalText(
        english: "Too many requests. Please try again later.",
        japanese: "送信回数が多すぎます。しばらくしてからお試しください。"
      )
    case .deliveryFailed, .serverError, .invalidResponse:
      return localizedLegalText(
        english: "Your message could not be sent. Please try again later.",
        japanese: "送信できませんでした。しばらくしてからお試しください。"
      )
    case .networkUnavailable:
      return localizedLegalText(
        english: "Check your connection and try again.",
        japanese: "通信環境を確認して、もう一度お試しください。"
      )
    case .timedOut:
      return localizedLegalText(
        english: "The request timed out. Please try again.",
        japanese: "通信がタイムアウトしました。もう一度お試しください。"
      )
    }
  }
}
