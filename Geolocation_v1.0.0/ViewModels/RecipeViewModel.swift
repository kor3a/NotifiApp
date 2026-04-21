//
//  RecipeViewModel.swift
//  Geolocation_v1.0.0
//
//  Created by Claude on 3/27/26.
//

import Foundation
import FirebaseFirestore

class RecipeViewModel: ObservableObject {
    @Published var recipes: [Recipe] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var isSavingIngredients: Bool = false

    private let db = Firestore.firestore()
    private let sessionManager = UserSessionManager.shared
    private var listener: ListenerRegistration?

    deinit {
        listener?.remove()
    }

    private var currentUserId: String? {
        sessionManager.currentUser?.userId
    }

    // MARK: - Fetch

    func fetchRecipes() {
        guard let userId = currentUserId else { return }
        isLoading = true
        listener?.remove()
        listener = db.collection("recipes")
            .whereField("userId", isEqualTo: userId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    self.isLoading = false
                    if let error = error {
                        self.errorMessage = error.localizedDescription
                        return
                    }
                    self.recipes = (snapshot?.documents.compactMap { doc -> Recipe? in
                        let data = doc.data()
                        guard let name = data["name"] as? String,
                              let ingredients = data["ingredients"] as? [String],
                              let createdAt = data["createdAt"] as? TimeInterval else { return nil }
                        return Recipe(id: doc.documentID, name: name, ingredients: ingredients, createdAt: createdAt)
                    } ?? []).sorted { $0.createdAt < $1.createdAt }
                }
            }
    }

    // MARK: - Create / Update / Delete

    func addRecipe(name: String, ingredients: [String]) {
        guard let userId = currentUserId,
              let userEmail = sessionManager.currentUser?.email else { return }
        let docRef = db.collection("recipes").document()
        let data: [String: Any] = [
            "userId": userId,
            "userEmail": userEmail,
            "name": name,
            "ingredients": ingredients,
            "createdAt": Date().timeIntervalSince1970
        ]
        docRef.setData(data)
    }

    func updateRecipe(_ recipe: Recipe, name: String, ingredients: [String]) {
        db.collection("recipes").document(recipe.id)
            .updateData(["name": name, "ingredients": ingredients])
    }

    func deleteRecipe(_ recipe: Recipe) {
        db.collection("recipes").document(recipe.id).delete()
    }

    // MARK: - Add Ingredients to Store

    /// Adds all ingredients from the recipe to the given store as reminders (skips duplicates).
    /// Calls completion with the number of ingredients actually added.
    func addIngredientsToStore(_ recipe: Recipe, userStoreItem: UserStoreItem, completion: @escaping (Int) -> Void) {
        let userStoreId = userStoreItem.reminderStoreId
        let sharedWith = userStoreItem.sharedWith
        let sharedFromName = userStoreItem.sharedFromName
        let isSharedStore = (sharedWith != nil && !sharedWith!.isEmpty) || sharedFromName != nil

        isSavingIngredients = true

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

                for ingredient in recipe.ingredients {
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

                        // Recipient perspective first so merge recipients don't
                        // fall through to the owner branch and lose attribution.
                        if let sharedFromName = sharedFromName {
                            reminderData["sharedWith"] = [sharedFromName]
                        } else if let sharedWith = sharedWith, !sharedWith.isEmpty {
                            reminderData["sharedWith"] = sharedWith
                        }

                        // Persist creator attribution so the other side renders
                        // the correct sharer without relying on backfill.
                        if let currentUserName = UserSessionManager.shared.currentUser?.name {
                            reminderData["sharedFrom"] = currentUserName
                        }
                        if let currentUserId = UserSessionManager.shared.currentUser?.userId {
                            reminderData["sharedFromId"] = currentUserId
                        }
                    }

                    batch.setData(reminderData, forDocument: docRef)
                    addedCount += 1
                }

                guard addedCount > 0 else {
                    DispatchQueue.main.async {
                        self.isSavingIngredients = false
                        completion(0)
                    }
                    return
                }

                batch.commit { error in
                    DispatchQueue.main.async {
                        self.isSavingIngredients = false
                        completion(error == nil ? addedCount : 0)
                    }
                }
            }
    }
}
