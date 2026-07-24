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
    ///
    /// Free-tier accounts are limited to `SubscriptionManager.freeReminderLimitPerStore`
    /// items per store: when the bulk add would push the store past the limit,
    /// nothing is added and `onLimitExceeded` is called instead (stores already
    /// over the limit keep their existing items).
    ///
    /// When `useSmartCategory` is true (subscriber with Smart Category enabled for
    /// this store), the newly added ingredients are auto-categorized in the
    /// background after the batch commits, matching the behaviour of items added
    /// manually or through Smart Recipe.
    func addIngredientsToStore(
        _ recipe: Recipe,
        userStoreItem: UserStoreItem,
        isSubscribed: Bool,
        useSmartCategory: Bool = false,
        completion: @escaping (Int) -> Void,
        onLimitExceeded: @escaping () -> Void
    ) {
        let userStoreId = userStoreItem.reminderStoreId
        let storeSharedWith = userStoreItem.sharedWith
        let sharedFromName = userStoreItem.sharedFromName

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

                // Owner's user_store.sharedWith is only written when the recipient
                // accepts and userStoreItem may be stale, so recover the recipient
                // list from reminders already marked shared (excluding the current
                // user) when the store's own sharedWith is empty. This keeps
                // bulk-added ingredients flagged shared like existing items.
                let sharedWith: [String]?
                if let storeSharedWith = storeSharedWith, !storeSharedWith.isEmpty {
                    sharedWith = storeSharedWith
                } else {
                    let currentUserName = UserSessionManager.shared.currentUser?.name
                    let recovered = Set(
                        (snapshot?.documents ?? []).compactMap { doc -> [String]? in
                            (doc.data()["isShared"] as? Bool) == true
                                ? doc.data()["sharedWith"] as? [String]
                                : nil
                        }.flatMap { $0 }
                    ).subtracting([currentUserName].compactMap { $0 })
                    sharedWith = recovered.isEmpty ? nil : Array(recovered)
                }
                let isSharedStore = (sharedWith != nil && !sharedWith!.isEmpty) || sharedFromName != nil

                let batch = self.db.batch()
                var addedCount = 0
                // Doc ids of the ingredients written by this batch, kept so they
                // can be auto-categorized once the commit succeeds.
                var addedIngredients: [(docId: String, title: String)] = []

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
                    addedIngredients.append((docId: docRef.documentID, title: ingredient))
                    addedCount += 1
                }

                guard addedCount > 0 else {
                    DispatchQueue.main.async {
                        self.isSavingIngredients = false
                        completion(0)
                    }
                    return
                }

                // Free-tier item limit: block the bulk add when it would push the
                // store past the per-store limit for non-subscribed users.
                let existingCount = snapshot?.documents.count ?? 0
                if !isSubscribed
                    && existingCount + addedCount > SubscriptionManager.freeReminderLimitPerStore {
                    DispatchQueue.main.async {
                        self.isSavingIngredients = false
                        onLimitExceeded()
                    }
                    return
                }

                batch.commit { error in
                    DispatchQueue.main.async {
                        self.isSavingIngredients = false
                        completion(error == nil ? addedCount : 0)

                        // Auto-categorize the newly added ingredients for
                        // subscribers with Smart Category on. Runs after the
                        // completion handler so the confirmation isn't delayed
                        // by the network round trip.
                        if error == nil && useSmartCategory {
                            self.categorizeAddedIngredients(addedIngredients)
                        }
                    }
                }
            }
    }

    /// Auto-categorize ingredients that were just added to a store.
    ///
    /// Intentionally holds a strong reference to `self` so categorization still
    /// finishes when the recipe picker sheet is dismissed right after adding.
    private func categorizeAddedIngredients(_ ingredients: [(docId: String, title: String)]) {
        guard !ingredients.isEmpty else { return }

        let titles = ingredients.map { $0.title }
        Task {
            do {
                let mapping = try await OpenAIService.shared.categorizeItems(titles)
                // Fallback lookup: the model occasionally echoes an item back with
                // different casing/whitespace, which would drop the category.
                let normalizedMapping = Dictionary(
                    mapping.map { ($0.key.lowercased().trimmingCharacters(in: .whitespacesAndNewlines), $0.value) },
                    uniquingKeysWith: { first, _ in first }
                )

                let batch = self.db.batch()
                var updatedCount = 0

                for ingredient in ingredients {
                    let normalizedTitle = ingredient.title
                        .lowercased()
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    guard let category = mapping[ingredient.title] ?? normalizedMapping[normalizedTitle],
                          category != "Uncategorized", !category.isEmpty else { continue }

                    let docRef = self.db.collection("reminders").document(ingredient.docId)
                    batch.updateData(["category": category], forDocument: docRef)
                    updatedCount += 1
                }

                if updatedCount > 0 {
                    try await batch.commit()
                    #if DEBUG
                    print("RecipeViewModel: Auto-categorized \(updatedCount) ingredient(s)")
                    #endif
                }
            } catch {
                #if DEBUG
                print("RecipeViewModel: Auto-categorization failed: \(error.localizedDescription)")
                #endif
                // Non-critical failure — ingredients are added, just uncategorized
            }
        }
    }
}
