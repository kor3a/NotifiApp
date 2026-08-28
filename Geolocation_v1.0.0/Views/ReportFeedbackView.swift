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
    @Environment(\.colorScheme) private var colorScheme

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
        ZStack {
            OrganicPalette.canvas(colorScheme)
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    categorySection

                    messageSection

                    OrganicPillButton(
                        title: isSending ? "Sending…" : "Submit Feedback",
                        isLoading: isSending,
                        fillsWidth: true
                    ) {
                        submitFeedback()
                    }
                    .disabled(!canSubmit)
                    .padding(.top, 4)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(OrganicPalette.canvas(colorScheme), for: .navigationBar)
        .tint(OrganicPalette.terracotta(colorScheme))
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Report & Feedback")
                    .font(OrganicPalette.title(17))
                    .foregroundColor(OrganicPalette.ink(colorScheme))
            }
        }
        .organicAlert(
            "Thank you!",
            isPresented: $showConfirmation,
            icon: "heart.fill",
            tone: .success,
            message: "Your feedback has been submitted. We appreciate you helping improve Allim!",
            actions: [.ok()]
        )
        .organicAlert(
            "Couldn't Send Feedback",
            isPresented: $showError,
            icon: "exclamationmark.triangle.fill",
            tone: .destructive,
            message: errorMessage,
            actions: [.ok()]
        )
    }

    // MARK: - Sections

    /// Three cards rather than a picker: there are only three answers, and each
    /// one gets a glyph that says what it is faster than the label does.
    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            OrganicSectionLabel(title: "What's this about?")

            ForEach(FeedbackCategory.allCases) { category in
                Button {
                    selectedCategory = category
                } label: {
                    categoryRow(for: category)
                }
                .buttonStyle(.plain)
                .disabled(isSending)
            }
        }
    }

    private func categoryRow(for category: FeedbackCategory) -> some View {
        let isSelected = selectedCategory == category

        return HStack(spacing: 14) {
            Image(systemName: category.icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(
                    isSelected ? .white : OrganicPalette.terracotta(colorScheme)
                )
                .frame(width: 38, height: 38)
                .background(
                    Circle().fill(
                        isSelected
                            ? OrganicPalette.terracotta(colorScheme)
                            : OrganicPalette.blush(colorScheme)
                    )
                )

            Text(category.rawValue)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(OrganicPalette.ink(colorScheme))

            Spacer(minLength: 8)

            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 20))
                .foregroundColor(
                    isSelected
                        ? OrganicPalette.terracotta(colorScheme)
                        : OrganicPalette.outline(colorScheme)
                )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(OrganicCardBackground(colorScheme: colorScheme))
        .contentShape(Rectangle())
    }

    private var messageSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            OrganicSectionLabel(title: "Message")

            Text("Describe your feedback or issue in as much detail as possible.")
                .font(.system(size: 14))
                .foregroundColor(OrganicPalette.inkSoft(colorScheme))

            ZStack(alignment: .topLeading) {
                // TextEditor has no prompt of its own, so the placeholder is
                // drawn behind it and hidden once there is anything to read.
                if messageText.isEmpty {
                    Text("What happened?")
                        .font(.system(size: 16))
                        .foregroundColor(OrganicPalette.inkSoft(colorScheme).opacity(0.8))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 20)
                }

                TextEditor(text: $messageText)
                    .font(.system(size: 16))
                    .foregroundColor(OrganicPalette.ink(colorScheme))
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 15)
                    .padding(.vertical, 12)
                    .frame(minHeight: 180)
                    .disabled(isSending)
            }
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(OrganicPalette.field(colorScheme))
            )
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
