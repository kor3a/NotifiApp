//
//  ReportFeedbackView.swift
//  Geolocation_v1.0.0
//

import SwiftUI
import FirebaseFunctions

struct ReportFeedbackView: View {

    @State private var selectedCategory: FeedbackCategory = .feedback
    @State private var messageText: String = ""
    @State private var isSending = false
    @State private var showConfirmation = false
    @State private var showError = false
    @State private var errorMessage = ""
    @ObservedObject private var sessionManager = UserSessionManager.shared

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

    private var canSubmit: Bool {
        !trimmedMessage.isEmpty && !isSending
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
                    .disabled(isSending)
            }

            Section {
                Button {
                    submitFeedback()
                } label: {
                    HStack {
                        Spacer()
                        if isSending {
                            ProgressView()
                                .padding(.trailing, 8)
                            Text("Sending…")
                        } else {
                            Text("Submit Feedback")
                        }
                        Spacer()
                    }
                }
                .foregroundStyle(canSubmit ? Color.blue : Color.secondary)
                .disabled(!canSubmit)
            }
        }
        .navigationTitle("Report & Feedback")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Thank you!", isPresented: $showConfirmation) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Your feedback has been submitted. We appreciate you helping improve Allim!")
        }
        .alert("Couldn't Send Feedback", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }

    /// Sends the feedback to the backend `submitFeedback` Cloud Function, which
    /// archives it in Firestore and emails the team. The user stays in the app
    /// and gets an immediate success or failure alert.
    private func submitFeedback() {
        let message = trimmedMessage
        guard !message.isEmpty else { return }

        isSending = true

        let payload: [String: Any] = [
            "category": selectedCategory.rawValue,
            "message": message,
            "appVersion": appVersion,
            "reporterName": sessionManager.currentUser?.name ?? "",
            "reporterUserId": sessionManager.currentUser?.userId ?? "",
        ]

        Functions.functions().httpsCallable("submitFeedback").call(payload) { _, error in
            isSending = false

            if let error = error {
                #if DEBUG
                print("ReportFeedbackView: submitFeedback failed: \(error.localizedDescription)")
                #endif
                errorMessage = "Something went wrong while sending your feedback. Please check your connection and try again."
                showError = true
                return
            }

            messageText = ""
            showConfirmation = true
        }
    }
}
