//
//  ReportFeedbackView.swift
//  Geolocation_v1.0.0
//

import SwiftUI
import MessageUI

struct ReportFeedbackView: View {

    /// Destination address for feedback and bug reports.
    private static let supportEmail = "jjamesubongdev@gmail.com"

    @State private var selectedCategory: FeedbackCategory = .feedback
    @State private var messageText: String = ""
    @State private var showConfirmation = false
    @State private var showMailComposer = false
    @State private var showMailUnavailableAlert = false
    @State private var mailResult: MFMailComposeResult?
    @Environment(\.openURL) private var openURL

    enum FeedbackCategory: String, CaseIterable, Identifiable {
        case feedback = "General Feedback"
        case bug = "Report a Bug"
        case feature = "Feature Request"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .feedback: return "bubble.left.fill"
            case .bug: return "ant.fill"
            case .feature: return "lightbulb.fill"
            }
        }
    }

    private var trimmedMessage: String {
        messageText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        Form {
            Section(header: Text("Category")) {
                Picker("Category", selection: $selectedCategory) {
                    ForEach(FeedbackCategory.allCases) { category in
                        Label(category.rawValue, systemImage: category.icon)
                            .tag(category)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }

            Section(header: Text("Message"), footer: Text("Describe your feedback or issue in as much detail as possible.")) {
                TextEditor(text: $messageText)
                    .frame(minHeight: 120)
            }

            Section {
                Button("Send via Email") {
                    sendEmail()
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .foregroundStyle(trimmedMessage.isEmpty ? Color.secondary : Color.blue)
                .disabled(trimmedMessage.isEmpty)
            }
        }
        .navigationTitle("Report & Feedback")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showMailComposer) {
            MailComposeView(
                recipients: [Self.supportEmail],
                subject: emailSubject,
                body: emailBody
            ) { result in
                mailResult = result
                if result == .sent {
                    showConfirmation = true
                    messageText = ""
                }
            }
        }
        .alert("Thank you!", isPresented: $showConfirmation) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Your feedback has been submitted. We appreciate you helping improve Allim!")
        }
        .alert("Mail Not Set Up", isPresented: $showMailUnavailableAlert) {
            Button("Copy Email Address") {
                UIPasteboard.general.string = Self.supportEmail
            }
            Button("OK", role: .cancel) { }
        } message: {
            Text("No email account is set up on this device. You can reach us directly at \(Self.supportEmail).")
        }
    }

    private var emailSubject: String {
        "Allim – \(selectedCategory.rawValue)"
    }

    private var emailBody: String {
        """
        \(messageText)


        ––––––––––
        Sent from Allim
        \(appVersionLine)
        """
    }

    private var appVersionLine: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "App Version: \(version) (\(build))"
    }

    private func sendEmail() {
        // Preferred: in-app mail composer when a Mail account is configured.
        if MFMailComposeViewController.canSendMail() {
            showMailComposer = true
            return
        }

        // Fallback: hand off to the default mail client via a mailto link.
        let encodedSubject = emailSubject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedBody = emailBody.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let mailtoString = "mailto:\(Self.supportEmail)?subject=\(encodedSubject)&body=\(encodedBody)"

        if let url = URL(string: mailtoString) {
            openURL(url) { accepted in
                if !accepted {
                    showMailUnavailableAlert = true
                }
            }
        } else {
            showMailUnavailableAlert = true
        }
    }
}

/// SwiftUI wrapper around `MFMailComposeViewController` so feedback can be
/// composed and sent without leaving the app.
struct MailComposeView: UIViewControllerRepresentable {
    @Environment(\.presentationMode) private var presentationMode

    let recipients: [String]
    let subject: String
    let body: String
    var onResult: (MFMailComposeResult) -> Void

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let composer = MFMailComposeViewController()
        composer.mailComposeDelegate = context.coordinator
        composer.setToRecipients(recipients)
        composer.setSubject(subject)
        composer.setMessageBody(body, isHTML: false)
        return composer
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let parent: MailComposeView

        init(_ parent: MailComposeView) {
            self.parent = parent
        }

        func mailComposeController(_ controller: MFMailComposeViewController,
                                   didFinishWith result: MFMailComposeResult,
                                   error: Error?) {
            parent.onResult(result)
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}
