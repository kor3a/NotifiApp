//
//  SmartRecipeViewModel.swift
//  Geolocation_v1.0.0
//
//  Created by Claude on 2/20/26.
//

import Foundation
import FirebaseFirestore

struct RecipeChatMessage: Identifiable, Equatable {
    let id = UUID()
    let role: MessageRole
    let content: String
    let timestamp: Date
    var ingredients: [String]?

    enum MessageRole {
        case user
        case assistant
    }

    init(role: MessageRole, content: String, ingredients: [String]? = nil) {
        self.role = role
        self.content = content
        self.timestamp = Date()
        self.ingredients = ingredients
    }

    static func == (lhs: RecipeChatMessage, rhs: RecipeChatMessage) -> Bool {
        lhs.id == rhs.id && lhs.ingredients == rhs.ingredients
    }
}

@MainActor
class SmartRecipeViewModel: ObservableObject {
    @Published var messages: [RecipeChatMessage] = []
    @Published var inputText: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var isSavingIngredients: Bool = false
    @Published var savedIngredientsCount: Int?
    @Published var savedToStoreName: String?
    @Published var savedRecipeName: String?

    private let openAIService = OpenAIService.shared
    private let db = Firestore.firestore()

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
                var assistantMessage = RecipeChatMessage(role: .assistant, content: response)
                messages.append(assistantMessage)
                isLoading = false

                // Extract ingredients in the background
                if let ingredients = try? await openAIService.extractIngredients(from: response),
                   !ingredients.isEmpty {
                    // Update the last message with extracted ingredients
                    if let lastIndex = messages.indices.last,
                       messages[lastIndex].id == assistantMessage.id {
                        assistantMessage.ingredients = ingredients
                        messages[lastIndex] = assistantMessage
                    }
                }
            } catch {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }

    func addIngredientsToStore(messageId: UUID, userStoreItem: UserStoreItem) {
        guard let message = messages.first(where: { $0.id == messageId }),
              let ingredients = message.ingredients, !ingredients.isEmpty else { return }

        let userStoreId = userStoreItem.reminderStoreId
        let sharedWith = userStoreItem.sharedWith
        let sharedFromName = userStoreItem.sharedFromName
        let isSharedStore = (sharedWith != nil && !sharedWith!.isEmpty) || sharedFromName != nil

        isSavingIngredients = true
        savedIngredientsCount = nil
        savedToStoreName = nil

        // Fetch existing reminders for this store to find current max sortOrder and check duplicates
        db.collection("reminders")
            .whereField("userStoreId", isEqualTo: userStoreId)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }

                let existingTitles = Set(
                    (snapshot?.documents ?? []).compactMap {
                        ($0.data()["title"] as? String)?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                )
                let maxSortOrder = (snapshot?.documents ?? []).compactMap {
                    $0.data()["sortOrder"] as? Int
                }.max() ?? -1

                let batch = self.db.batch()
                var addedCount = 0
                var addedIngredients: [(docId: String, title: String)] = []

                for ingredient in ingredients {
                    let normalized = ingredient.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !normalized.isEmpty, !existingTitles.contains(normalized) else { continue }

                    let docRef = self.db.collection("reminders").document()
                    var reminderData: [String: Any] = [
                        "userStoreId": userStoreId,
                        "title": ingredient,
                        "isDone": false,
                        "createdAt": Date().timeIntervalSince1970,
                        "sortOrder": maxSortOrder + 1 + addedCount
                    ]

                    if isSharedStore {
                        reminderData["isShared"] = true
                        reminderData["sharedAt"] = Date().timeIntervalSince1970
                        if let sharedWith = sharedWith, !sharedWith.isEmpty {
                            reminderData["sharedWith"] = sharedWith
                        } else if let sharedFromName = sharedFromName {
                            reminderData["sharedWith"] = [sharedFromName]
                        }
                    }

                    batch.setData(reminderData, forDocument: docRef)
                    addedIngredients.append((docId: docRef.documentID, title: ingredient))
                    addedCount += 1
                }

                guard addedCount > 0 else {
                    DispatchQueue.main.async {
                        self.isSavingIngredients = false
                        self.errorMessage = "All ingredients already exist in this store"
                    }
                    return
                }

                batch.commit { error in
                    DispatchQueue.main.async {
                        self.isSavingIngredients = false
                        if let error = error {
                            self.errorMessage = "Failed to add ingredients: \(error.localizedDescription)"
                        } else {
                            self.savedIngredientsCount = addedCount
                            self.savedToStoreName = userStoreItem.store.name

                            // Auto-categorize the newly added ingredients
                            self.categorizeAddedIngredients(addedIngredients)
                        }
                    }
                }
            }
    }

    /// Auto-categorize ingredients that were just added to a store
    private func categorizeAddedIngredients(_ ingredients: [(docId: String, title: String)]) {
        guard !ingredients.isEmpty else { return }

        let titles = ingredients.map { $0.title }
        Task {
            do {
                let mapping = try await openAIService.categorizeItems(titles)
                let batch = db.batch()
                var hasUpdates = false

                for ingredient in ingredients {
                    if let category = mapping[ingredient.title], category != "Uncategorized" {
                        let docRef = db.collection("reminders").document(ingredient.docId)
                        batch.updateData(["category": category], forDocument: docRef)
                        hasUpdates = true
                    }
                }

                if hasUpdates {
                    try await batch.commit()
                    #if DEBUG
                    print("SmartRecipeViewModel: Auto-categorized \(mapping.count) ingredients")
                    #endif
                }
            } catch {
                #if DEBUG
                print("SmartRecipeViewModel: Auto-categorization failed: \(error.localizedDescription)")
                #endif
                // Non-critical failure — ingredients are added, just uncategorized
            }
        }
    }

    func addRecipeToList(messageId: UUID) {
        guard let message = messages.first(where: { $0.id == messageId }),
              let ingredients = message.ingredients, !ingredients.isEmpty else { return }

        guard let userId = UserSessionManager.shared.currentUser?.userId,
              let userEmail = UserSessionManager.shared.currentUser?.email else {
            errorMessage = "Please sign in to save recipes"
            return
        }

        let name = extractRecipeName(from: message.content)
        let docRef = db.collection("recipes").document()
        let data: [String: Any] = [
            "userId": userId,
            "userEmail": userEmail,
            "name": name,
            "ingredients": ingredients,
            "createdAt": Date().timeIntervalSince1970
        ]

        isSavingIngredients = true
        savedRecipeName = nil

        docRef.setData(data) { [weak self] error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isSavingIngredients = false
                if let error = error {
                    self.errorMessage = "Failed to save recipe: \(error.localizedDescription)"
                } else {
                    self.savedRecipeName = name
                }
            }
        }
    }

    private func extractRecipeName(from content: String) -> String {
        for line in content.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("### ") { return String(trimmed.dropFirst(4)).trimmingCharacters(in: .whitespaces) }
            if trimmed.hasPrefix("## ") { return String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces) }
            if trimmed.hasPrefix("# ") { return String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces) }
        }
        return "Smart Recipe"
    }

    func clearSavedConfirmation() {
        savedIngredientsCount = nil
        savedToStoreName = nil
        savedRecipeName = nil
    }

    func startNewChat() {
        messages = []
        inputText = ""
        isLoading = false
        errorMessage = nil
        isSavingIngredients = false
        savedIngredientsCount = nil
        savedToStoreName = nil
        savedRecipeName = nil
    }
}
