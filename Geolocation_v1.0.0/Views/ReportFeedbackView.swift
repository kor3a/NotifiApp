//
//  ReportFeedbackView.swift
//  Geolocation_v1.0.0
//

import SwiftUI

struct ReportFeedbackView: View {

    @State private var selectedCategory: FeedbackCategory = .feedback
    @State private var messageText: String = ""
    @State private var showConfirmation = false
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
                .foregroundStyle(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.secondary : Color.blue)
                .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .navigationTitle("Report & Feedback")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Thank you!", isPresented: $showConfirmation) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Your feedback has been submitted. We appreciate you helping improve Allim!")
        }
    }

    private func sendEmail() {
        let subject = selectedCategory.rawValue
        let body = messageText
        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let mailtoString = "mailto:support@allimapp.com?subject=\(encodedSubject)&body=\(encodedBody)"
        if let url = URL(string: mailtoString) {
            openURL(url)
        }
    }
}
