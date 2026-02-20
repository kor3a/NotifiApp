//
//  AIRecipeViewModel.swift
//  Geolocation_v1.0.0
//
//  Created by Claude on 2/20/26.
//

import Foundation

struct RecipeChatMessage: Identifiable, Equatable {
    let id = UUID()
    let role: MessageRole
    let content: String
    let timestamp: Date

    enum MessageRole {
        case user
        case assistant
    }

    init(role: MessageRole, content: String) {
        self.role = role
        self.content = content
        self.timestamp = Date()
    }
}

@MainActor
class AIRecipeViewModel: ObservableObject {
    @Published var messages: [RecipeChatMessage] = []
    @Published var inputText: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let openAIService = OpenAIService.shared

    func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        let userMessage = RecipeChatMessage(role: .user, content: text)
        messages.append(userMessage)
        inputText = ""
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let chatMessages = messages.map { message in
                    OpenAIService.ChatMessage(
                        role: message.role == .user ? "user" : "assistant",
                        content: message.content
                    )
                }

                let response = try await openAIService.sendMessage(messages: chatMessages)
                let assistantMessage = RecipeChatMessage(role: .assistant, content: response)
                messages.append(assistantMessage)
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}
