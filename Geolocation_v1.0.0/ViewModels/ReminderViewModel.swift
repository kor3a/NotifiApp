//
//  ReminderViewModel.swift
//  Geolocation_v1.0.0
//
//  Created by Claude on 11/6/24.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
import FirebaseStorage
import UIKit

class ReminderViewModel: ObservableObject {
    private let db = Firestore.firestore()
    @Published var reminders: [Reminder] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String = ""
    /// Flag to prevent snapshot listener from overwriting local state during a reorder operation
    private var isReordering = false

    /// Fetch reminders for a specific user_store document
    /// - Parameters:
    ///   - userStoreId: The user_store ID to fetch reminders for
    ///   - sharedFromName: If this is a shared store, the name of the user who shared it (to populate sharedFrom on reminders)
    func fetchReminders(for userStoreId: String, sharedFromName: String? = nil) {
        isLoading = true
        #if DEBUG
        print("ReminderViewModel: Fetching reminders for userStoreId: \(userStoreId), sharedFromName: \(sharedFromName ?? "nil")")
        #endif

        db.collection("reminders")
            .whereField("userStoreId", isEqualTo: userStoreId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }

                DispatchQueue.main.async {
                    self.isLoading = false

                    if let error = error {
                        #if DEBUG
                        print("ReminderViewModel: Error fetching reminders: \(error.localizedDescription)")
                        print("ReminderViewModel: Full error: \(error)")
                        #endif
                        self.errorMessage = "Error fetching reminders: \(error.localizedDescription)"
                        return
                    }

                    guard let documents = snapshot?.documents else {
                        #if DEBUG
                        print("ReminderViewModel: No reminders found (nil documents)")
                        #endif
                        self.reminders = []
                        return
                    }

                    #if DEBUG
                    print("ReminderViewModel: Found \(documents.count) reminder documents")
                    #endif

                    let fetchedReminders = documents.compactMap { doc -> Reminder? in
                        let data = doc.data()
                        #if DEBUG
                        print("ReminderViewModel: Processing document \(doc.documentID): \(data)")
                        #endif

                        guard let userStoreId = data["userStoreId"] as? String,
                              let title = data["title"] as? String,
                              let isDone = data["isDone"] as? Bool,
                              let createdAt = data["createdAt"] as? TimeInterval else {
                            #if DEBUG
                            print("ReminderViewModel: Missing fields in reminder document \(doc.documentID)")
                            #endif
                            return nil
                        }

                        // Parse optional shared fields
                        let isShared = data["isShared"] as? Bool
                        var sharedFrom = data["sharedFrom"] as? String
                        let sharedAt = data["sharedAt"] as? TimeInterval
                        let sharedReminderId = data["sharedReminderId"] as? String
                        let sharedWith = data["sharedWith"] as? [String]

                        // If viewing a shared store and reminder is shared but has no sharedFrom,
                        // populate it with the store owner's name for proper display
                        if isShared == true && sharedFrom == nil && sharedFromName != nil {
                            sharedFrom = sharedFromName
                        }

                        let photoURLs = data["photoURLs"] as? [String]
                        let sortOrder = data["sortOrder"] as? Int
                        let quantity = data["quantity"] as? Int
                        let isOutOfStock = data["isOutOfStock"] as? Bool
                        let category = data["category"] as? String

                        return Reminder(
                            id: doc.documentID,
                            userStoreId: userStoreId,
                            title: title,
                            isDone: isDone,
                            createdAt: createdAt,
                            isShared: isShared,
                            sharedFrom: sharedFrom,
                            sharedAt: sharedAt,
                            sharedReminderId: sharedReminderId,
                            sharedWith: sharedWith,
                            photoURLs: photoURLs,
                            sortOrder: sortOrder,
                            quantity: quantity,
                            isOutOfStock: isOutOfStock,
                            category: category
                        )
                    }

                    // Skip snapshot update while a reorder operation is in progress
                    if self.isReordering { return }

                    // Sort by sortOrder first (if available), then by createdAt
                    self.reminders = fetchedReminders.sorted { a, b in
                        let orderA = a.sortOrder ?? Int.max
                        let orderB = b.sortOrder ?? Int.max
                        if orderA != orderB {
                            return orderA < orderB
                        }
                        return a.createdAt < b.createdAt
                    }

                    #if DEBUG
                    print("ReminderViewModel: Successfully loaded \(self.reminders.count) reminders")
                    #endif
                }
            }
    }

    // MARK: - Category Grouping

    /// All distinct categories present in the current reminders, sorted alphabetically,
    /// with "Uncategorized" (nil category) always at the end.
    var categoryOrder: [String] {
        var cats = Set<String>()
        var hasUncategorized = false
        for r in reminders {
            if let cat = r.category, !cat.isEmpty {
                cats.insert(cat)
            } else {
                hasUncategorized = true
            }
        }
        var sorted = cats.sorted()
        if hasUncategorized {
            sorted.append("Uncategorized")
        }
        return sorted
    }

    /// Reminders grouped by category. Key is the display category name.
    func reminders(for category: String) -> [Reminder] {
        if category == "Uncategorized" {
            return reminders.filter { $0.category == nil || $0.category?.isEmpty == true }
        }
        return reminders.filter { $0.category == category }
    }

    /// Whether we should display reminders in category sections (true when at least one reminder has a category)
    var hasCategorizedReminders: Bool {
        reminders.contains { $0.category != nil && $0.category?.isEmpty == false }
    }

    /// Categorize a single reminder using AI and update Firestore
    func categorizeReminder(_ reminder: Reminder) {
        Task {
            do {
                let mapping = try await OpenAIService.shared.categorizeItems([reminder.title])
                let category = mapping[reminder.title] ?? "Uncategorized"
                await MainActor.run {
                    self.updateReminderCategory(reminder, newCategory: category == "Uncategorized" ? nil : category)
                }
            } catch {
                #if DEBUG
                print("ReminderViewModel: AI categorization failed for '\(reminder.title)': \(error.localizedDescription)")
                #endif
                // Leave category as nil — user can set it manually
            }
        }
    }

    /// Categorize all uncategorized reminders in the current store
    func categorizeUncategorizedReminders() {
        let uncategorized = reminders.filter { $0.category == nil || $0.category?.isEmpty == true }
        guard !uncategorized.isEmpty else { return }

        let titles = uncategorized.map { $0.title }
        Task {
            do {
                let mapping = try await OpenAIService.shared.categorizeItems(titles)
                await MainActor.run {
                    for reminder in uncategorized {
                        if let category = mapping[reminder.title], category != "Uncategorized" {
                            self.updateReminderCategory(reminder, newCategory: category)
                        }
                    }
                }
            } catch {
                #if DEBUG
                print("ReminderViewModel: Bulk AI categorization failed: \(error.localizedDescription)")
                #endif
            }
        }
    }

    /// Update a reminder's category — syncs across all linked shared reminders
    func updateReminderCategory(_ reminder: Reminder, newCategory: String?) {
        #if DEBUG
        print("ReminderViewModel: Updating category for '\(reminder.title)' to '\(newCategory ?? "nil")'")
        #endif

        let fieldValue: Any = newCategory ?? FieldValue.delete()

        if let sharedReminderId = reminder.sharedReminderId {
            db.collection("reminders")
                .whereField("sharedReminderId", isEqualTo: sharedReminderId)
                .getDocuments { [weak self] snapshot, error in
                    guard let self = self else { return }

                    if let error = error {
                        #if DEBUG
                        print("ReminderViewModel: Error finding linked reminders for category update: \(error.localizedDescription)")
                        #endif
                        self.updateSingleReminderCategory(reminder.id, category: fieldValue)
                        return
                    }

                    guard let documents = snapshot?.documents, !documents.isEmpty else {
                        self.updateSingleReminderCategory(reminder.id, category: fieldValue)
                        return
                    }

                    let batch = self.db.batch()
                    for doc in documents {
                        batch.updateData(["category": fieldValue], forDocument: doc.reference)
                    }

                    batch.commit { error in
                        DispatchQueue.main.async {
                            if let error = error {
                                #if DEBUG
                                print("ReminderViewModel: Error syncing category update: \(error.localizedDescription)")
                                #endif
                            } else {
                                #if DEBUG
                                print("ReminderViewModel: Synced category update across \(documents.count) linked reminders")
                                #endif
                            }
                        }
                    }
                }
        } else {
            updateSingleReminderCategory(reminder.id, category: fieldValue)
        }
    }

    private func updateSingleReminderCategory(_ reminderId: String, category: Any) {
        db.collection("reminders").document(reminderId).updateData([
            "category": category
        ]) { error in
            DispatchQueue.main.async {
                if let error = error {
                    #if DEBUG
                    print("ReminderViewModel: Error updating reminder category: \(error.localizedDescription)")
                    #endif
                } else {
                    #if DEBUG
                    print("ReminderViewModel: Reminder category updated successfully")
                    #endif
                }
            }
        }
    }

    /// Check whether a reminder with the given title already exists (case-insensitive) in the current store
    /// - Parameters:
    ///   - title: The title to check for duplicates
    ///   - excludingId: Optional reminder ID to exclude from the check (e.g., an autosaved reminder)
    func isDuplicateReminder(title: String, excludingId: String? = nil) -> Bool {
        let normalized = title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return reminders.contains {
            $0.title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == normalized &&
            (excludingId == nil || $0.id != excludingId)
        }
    }

    // MARK: - Favorite Tags

    @Published var favoriteTags: [FavoriteTag] = []
    private var favoriteTagsListener: ListenerRegistration?

    /// Fetch favorite tags for a specific user_store (real-time listener)
    func fetchFavoriteTags(for userStoreId: String) {
        favoriteTagsListener?.remove()

        favoriteTagsListener = db.collection("favorite_tags")
            .whereField("userStoreId", isEqualTo: userStoreId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }

                DispatchQueue.main.async {
                    if let error = error {
                        #if DEBUG
                        print("ReminderViewModel: Error fetching favorite tags: \(error.localizedDescription)")
                        #endif
                        return
                    }

                    guard let documents = snapshot?.documents else {
                        self.favoriteTags = []
                        return
                    }

                    self.favoriteTags = documents.compactMap { doc -> FavoriteTag? in
                        let data = doc.data()
                        guard let userStoreId = data["userStoreId"] as? String,
                              let title = data["title"] as? String,
                              let createdAt = data["createdAt"] as? TimeInterval else {
                            return nil
                        }
                        return FavoriteTag(
                            id: doc.documentID,
                            userStoreId: userStoreId,
                            title: title,
                            createdAt: createdAt
                        )
                    }.sorted { $0.createdAt < $1.createdAt }

                    #if DEBUG
                    print("ReminderViewModel: Loaded \(self.favoriteTags.count) favorite tags")
                    #endif
                }
            }
    }

    /// Check if a title already exists as a favorite tag (case-insensitive)
    func isFavoriteTag(title: String) -> Bool {
        let normalized = title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return favoriteTags.contains { $0.title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == normalized }
    }

    /// Add a reminder's title as a persistent favorite tag for the store
    func addFavoriteTag(userStoreId: String, title: String) {
        guard !isFavoriteTag(title: title) else {
            #if DEBUG
            print("ReminderViewModel: '\(title)' is already a favorite tag — skipping")
            #endif
            return
        }

        let tagData: [String: Any] = [
            "userStoreId": userStoreId,
            "title": title,
            "createdAt": Date().timeIntervalSince1970
        ]

        db.collection("favorite_tags").addDocument(data: tagData) { error in
            if let error = error {
                #if DEBUG
                print("ReminderViewModel: Error adding favorite tag: \(error.localizedDescription)")
                #endif
            } else {
                #if DEBUG
                print("ReminderViewModel: Favorite tag '\(title)' added successfully")
                #endif
            }
        }
    }

    /// Remove a favorite tag
    func removeFavoriteTag(_ tag: FavoriteTag) {
        db.collection("favorite_tags").document(tag.id).delete { error in
            if let error = error {
                #if DEBUG
                print("ReminderViewModel: Error removing favorite tag: \(error.localizedDescription)")
                #endif
            } else {
                #if DEBUG
                print("ReminderViewModel: Favorite tag '\(tag.title)' removed successfully")
                #endif
            }
        }
    }

    /// Add a reminder from a favorite tag tap (only if a reminder with that title doesn't already exist)
    func addReminderFromFavorite(tag: FavoriteTag, sharedWith: [String]? = nil, sharedFromName: String? = nil, currentUserName: String? = nil) {
        if isDuplicateReminder(title: tag.title) {
            #if DEBUG
            print("ReminderViewModel: Reminder '\(tag.title)' already exists — skipping add from favorite")
            #endif
            return
        }

        addReminder(
            userStoreId: tag.userStoreId,
            title: tag.title,
            sharedWith: sharedWith,
            sharedFromName: sharedFromName,
            currentUserName: currentUserName
        )
    }

    /// Add a new reminder
    /// - Parameters:
    ///   - userStoreId: The user_store ID to add the reminder to
    ///   - title: The reminder title
    ///   - sharedWith: If the store is shared (owner's perspective), the names of users it's shared with
    ///   - sharedFromName: If the store is shared (recipient's perspective), the name of the owner who shared the store
    ///   - currentUserName: The name of the user adding the reminder (for tracking who created it in shared stores)
    func addReminder(userStoreId: String, title: String, sharedWith: [String]? = nil, sharedFromName: String? = nil, currentUserName: String? = nil) {
        guard !title.isEmpty else {
            DispatchQueue.main.async {
                self.errorMessage = "Reminder title cannot be empty"
            }
            return
        }

        // Prevent case-insensitive duplicates within the same store
        if isDuplicateReminder(title: title) {
            #if DEBUG
            print("ReminderViewModel: Duplicate reminder '\(title)' — skipping add")
            #endif
            DispatchQueue.main.async {
                self.errorMessage = "'\(title)' already exists in this store"
            }
            return
        }

        #if DEBUG
        print("ReminderViewModel: Adding reminder '\(title)' for userStoreId: \(userStoreId), sharedWith: \(sharedWith ?? []), sharedFromName: \(sharedFromName ?? "nil"), currentUserName: \(currentUserName ?? "nil")")
        #endif

        // Place new reminder at the end of the current list
        let nextSortOrder = (self.reminders.compactMap { $0.sortOrder }.max() ?? -1) + 1

        var reminderData: [String: Any] = [
            "userStoreId": userStoreId,
            "title": title,
            "isDone": false,
            "createdAt": Date().timeIntervalSince1970,
            "sortOrder": nextSortOrder
        ]

        // Check if this is a shared store (either owner or recipient perspective)
        let isSharedStore = (sharedWith != nil && !sharedWith!.isEmpty) || sharedFromName != nil

        if isSharedStore {
            reminderData["isShared"] = true
            reminderData["sharedAt"] = Date().timeIntervalSince1970

            // Set sharedWith appropriately based on perspective
            if let sharedWith = sharedWith, !sharedWith.isEmpty {
                // Owner adding reminder - use their sharedWith list
                reminderData["sharedWith"] = sharedWith
            } else if let sharedFromName = sharedFromName {
                // Recipient adding reminder - mark as shared with the owner
                reminderData["sharedWith"] = [sharedFromName]
                // Also set sharedFrom to the current user (recipient) who created this reminder
                if let currentUserName = currentUserName {
                    reminderData["sharedFrom"] = currentUserName
                }
            }
        }

        db.collection("reminders").addDocument(data: reminderData) { [weak self] error in
            DispatchQueue.main.async {
                if let error = error {
                    #if DEBUG
                    print("ReminderViewModel: Error adding reminder: \(error.localizedDescription)")
                    #endif
                    self?.errorMessage = "Error adding reminder: \(error.localizedDescription)"
                } else {
                    #if DEBUG
                    print("ReminderViewModel: Reminder added successfully (isShared: \(isSharedStore))")
                    #endif
                    // Trigger AI categorization for the newly added reminder once it appears
                    // in the snapshot listener results
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        if let newReminder = self?.reminders.first(where: {
                            $0.title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                            && $0.category == nil
                        }) {
                            self?.categorizeReminder(newReminder)
                        }
                    }
                }
            }
        }
    }

    /// Move a reminder from one position to another and persist the new sort order
    func moveReminder(from source: IndexSet, to destination: Int) {
        isReordering = true
        reminders.move(fromOffsets: source, toOffset: destination)

        // Assign new sort orders based on current positions
        let batch = db.batch()
        for (index, reminder) in reminders.enumerated() {
            reminders[index].sortOrder = index
            let ref = db.collection("reminders").document(reminder.id)
            batch.updateData(["sortOrder": index], forDocument: ref)
        }

        batch.commit { [weak self] error in
            DispatchQueue.main.async {
                self?.isReordering = false
                if let error = error {
                    #if DEBUG
                    print("ReminderViewModel: Error updating sort orders: \(error.localizedDescription)")
                    #endif
                    self?.errorMessage = "Failed to update sort order: \(error.localizedDescription)"
                } else {
                    #if DEBUG
                    print("ReminderViewModel: Sort orders updated successfully")
                    #endif
                }
            }
        }
    }

    /// Toggle reminder isDone status - syncs across all linked shared reminders
    /// Also clears isOutOfStock when toggling isDone on
    func toggleReminder(_ reminder: Reminder) {
        #if DEBUG
        print("ReminderViewModel: Toggling reminder '\(reminder.title)'")
        #endif

        let newIsDone = !reminder.isDone
        var updateFields: [String: Any] = ["isDone": newIsDone]

        // Clear out-of-stock when marking as done via normal tap
        if newIsDone && reminder.isOutOfStock == true {
            updateFields["isOutOfStock"] = false
        }

        // If this reminder has a sharedReminderId, sync toggle across all linked reminders
        if let sharedReminderId = reminder.sharedReminderId {
            #if DEBUG
            print("ReminderViewModel: Syncing toggle across shared reminders with sharedReminderId: \(sharedReminderId)")
            #endif

            db.collection("reminders")
                .whereField("sharedReminderId", isEqualTo: sharedReminderId)
                .getDocuments { [weak self] snapshot, error in
                    guard let self = self else { return }

                    if let error = error {
                        #if DEBUG
                        print("ReminderViewModel: Error finding linked reminders: \(error.localizedDescription)")
                        #endif
                        // Fall back to updating just this reminder
                        self.updateSingleReminderFields(reminder.id, fields: updateFields)
                        return
                    }

                    guard let documents = snapshot?.documents, !documents.isEmpty else {
                        // No linked reminders found, update just this one
                        self.updateSingleReminderFields(reminder.id, fields: updateFields)
                        return
                    }

                    // Batch update all linked reminders
                    let batch = self.db.batch()
                    for doc in documents {
                        batch.updateData(updateFields, forDocument: doc.reference)
                    }

                    batch.commit { error in
                        DispatchQueue.main.async {
                            if let error = error {
                                #if DEBUG
                                print("ReminderViewModel: Error syncing toggle: \(error.localizedDescription)")
                                #endif
                            } else {
                                #if DEBUG
                                print("ReminderViewModel: Synced toggle across \(documents.count) linked reminders")
                                #endif
                            }
                        }
                    }
                }
        } else {
            // No sharing, just update this reminder
            updateSingleReminderFields(reminder.id, fields: updateFields)
        }
    }

    /// Toggle reminder out-of-stock status - syncs across all linked shared reminders
    /// When marking as out of stock, also clears isDone. When clearing out of stock, leaves isDone as false.
    func toggleOutOfStock(_ reminder: Reminder) {
        #if DEBUG
        print("ReminderViewModel: Toggling out-of-stock for reminder '\(reminder.title)'")
        #endif

        let newOutOfStock = !(reminder.isOutOfStock ?? false)
        var updateFields: [String: Any] = ["isOutOfStock": newOutOfStock]

        // When marking as out of stock, ensure isDone is false
        if newOutOfStock {
            updateFields["isDone"] = false
        }

        if let sharedReminderId = reminder.sharedReminderId {
            #if DEBUG
            print("ReminderViewModel: Syncing out-of-stock toggle across shared reminders with sharedReminderId: \(sharedReminderId)")
            #endif

            db.collection("reminders")
                .whereField("sharedReminderId", isEqualTo: sharedReminderId)
                .getDocuments { [weak self] snapshot, error in
                    guard let self = self else { return }

                    if let error = error {
                        #if DEBUG
                        print("ReminderViewModel: Error finding linked reminders for out-of-stock toggle: \(error.localizedDescription)")
                        #endif
                        self.updateSingleReminderOutOfStock(reminder.id, fields: updateFields)
                        return
                    }

                    guard let documents = snapshot?.documents, !documents.isEmpty else {
                        self.updateSingleReminderOutOfStock(reminder.id, fields: updateFields)
                        return
                    }

                    let batch = self.db.batch()
                    for doc in documents {
                        batch.updateData(updateFields, forDocument: doc.reference)
                    }

                    batch.commit { error in
                        DispatchQueue.main.async {
                            if let error = error {
                                #if DEBUG
                                print("ReminderViewModel: Error syncing out-of-stock toggle: \(error.localizedDescription)")
                                #endif
                            } else {
                                #if DEBUG
                                print("ReminderViewModel: Synced out-of-stock toggle across \(documents.count) linked reminders")
                                #endif
                            }
                        }
                    }
                }
        } else {
            updateSingleReminderOutOfStock(reminder.id, fields: updateFields)
        }
    }

    private func updateSingleReminderOutOfStock(_ reminderId: String, fields: [String: Any]) {
        db.collection("reminders").document(reminderId).updateData(fields) { error in
            DispatchQueue.main.async {
                if let error = error {
                    #if DEBUG
                    print("ReminderViewModel: Error toggling out-of-stock: \(error.localizedDescription)")
                    #endif
                } else {
                    #if DEBUG
                    print("ReminderViewModel: Reminder out-of-stock toggled successfully")
                    #endif
                }
            }
        }
    }

    /// Update reminder title - syncs across all linked shared reminders
    func updateReminderTitle(_ reminder: Reminder, newTitle: String) {
        let trimmedTitle = newTitle.trimmingCharacters(in: .whitespaces)
        guard !trimmedTitle.isEmpty, trimmedTitle != reminder.title else { return }

        #if DEBUG
        print("ReminderViewModel: Updating title for reminder '\(reminder.title)' to '\(trimmedTitle)'")
        #endif

        if let sharedReminderId = reminder.sharedReminderId {
            db.collection("reminders")
                .whereField("sharedReminderId", isEqualTo: sharedReminderId)
                .getDocuments { [weak self] snapshot, error in
                    guard let self = self else { return }

                    if let error = error {
                        #if DEBUG
                        print("ReminderViewModel: Error finding linked reminders for title update: \(error.localizedDescription)")
                        #endif
                        self.updateSingleReminderTitle(reminder.id, title: trimmedTitle)
                        return
                    }

                    guard let documents = snapshot?.documents, !documents.isEmpty else {
                        self.updateSingleReminderTitle(reminder.id, title: trimmedTitle)
                        return
                    }

                    let batch = self.db.batch()
                    for doc in documents {
                        batch.updateData(["title": trimmedTitle], forDocument: doc.reference)
                    }

                    batch.commit { error in
                        DispatchQueue.main.async {
                            if let error = error {
                                #if DEBUG
                                print("ReminderViewModel: Error syncing title update: \(error.localizedDescription)")
                                #endif
                            } else {
                                #if DEBUG
                                print("ReminderViewModel: Synced title update across \(documents.count) linked reminders")
                                #endif
                            }
                        }
                    }
                }
        } else {
            updateSingleReminderTitle(reminder.id, title: trimmedTitle)
        }
    }

    /// Update reminder quantity - syncs across all linked shared reminders
    /// Pass nil to remove the quantity
    func updateReminderQuantity(_ reminder: Reminder, newQuantity: Int?) {
        #if DEBUG
        print("ReminderViewModel: Updating quantity for reminder '\(reminder.title)' to \(newQuantity.map(String.init) ?? "nil")")
        #endif

        let fieldValue: Any = newQuantity ?? FieldValue.delete()

        if let sharedReminderId = reminder.sharedReminderId {
            db.collection("reminders")
                .whereField("sharedReminderId", isEqualTo: sharedReminderId)
                .getDocuments { [weak self] snapshot, error in
                    guard let self = self else { return }

                    if let error = error {
                        #if DEBUG
                        print("ReminderViewModel: Error finding linked reminders for quantity update: \(error.localizedDescription)")
                        #endif
                        self.updateSingleReminderQuantity(reminder.id, quantity: fieldValue)
                        return
                    }

                    guard let documents = snapshot?.documents, !documents.isEmpty else {
                        self.updateSingleReminderQuantity(reminder.id, quantity: fieldValue)
                        return
                    }

                    let batch = self.db.batch()
                    for doc in documents {
                        batch.updateData(["quantity": fieldValue], forDocument: doc.reference)
                    }

                    batch.commit { error in
                        DispatchQueue.main.async {
                            if let error = error {
                                #if DEBUG
                                print("ReminderViewModel: Error syncing quantity update: \(error.localizedDescription)")
                                #endif
                            } else {
                                #if DEBUG
                                print("ReminderViewModel: Synced quantity update across \(documents.count) linked reminders")
                                #endif
                            }
                        }
                    }
                }
        } else {
            updateSingleReminderQuantity(reminder.id, quantity: fieldValue)
        }
    }

    private func updateSingleReminderQuantity(_ reminderId: String, quantity: Any) {
        db.collection("reminders").document(reminderId).updateData([
            "quantity": quantity
        ]) { error in
            DispatchQueue.main.async {
                if let error = error {
                    #if DEBUG
                    print("ReminderViewModel: Error updating reminder quantity: \(error.localizedDescription)")
                    #endif
                } else {
                    #if DEBUG
                    print("ReminderViewModel: Reminder quantity updated successfully")
                    #endif
                }
            }
        }
    }

    private func updateSingleReminderTitle(_ reminderId: String, title: String) {
        db.collection("reminders").document(reminderId).updateData([
            "title": title
        ]) { error in
            DispatchQueue.main.async {
                if let error = error {
                    #if DEBUG
                    print("ReminderViewModel: Error updating reminder title: \(error.localizedDescription)")
                    #endif
                } else {
                    #if DEBUG
                    print("ReminderViewModel: Reminder title updated successfully")
                    #endif
                }
            }
        }
    }

    private func updateSingleReminder(_ reminderId: String, isDone: Bool) {
        db.collection("reminders").document(reminderId).updateData([
            "isDone": isDone
        ]) { error in
            DispatchQueue.main.async {
                if let error = error {
                    #if DEBUG
                    print("ReminderViewModel: Error toggling reminder: \(error.localizedDescription)")
                    #endif
                } else {
                    #if DEBUG
                    print("ReminderViewModel: Reminder toggled successfully")
                    #endif
                }
            }
        }
    }

    private func updateSingleReminderFields(_ reminderId: String, fields: [String: Any]) {
        db.collection("reminders").document(reminderId).updateData(fields) { error in
            DispatchQueue.main.async {
                if let error = error {
                    #if DEBUG
                    print("ReminderViewModel: Error updating reminder fields: \(error.localizedDescription)")
                    #endif
                } else {
                    #if DEBUG
                    print("ReminderViewModel: Reminder fields updated successfully")
                    #endif
                }
            }
        }
    }

    /// Delete a reminder - syncs deletion across all linked shared reminders
    func deleteReminder(_ reminder: Reminder) {
        #if DEBUG
        print("ReminderViewModel: Deleting reminder '\(reminder.title)'")
        #endif

        // If this reminder has a sharedReminderId, delete all linked reminders
        if let sharedReminderId = reminder.sharedReminderId {
            #if DEBUG
            print("ReminderViewModel: Syncing deletion across shared reminders with sharedReminderId: \(sharedReminderId)")
            #endif

            db.collection("reminders")
                .whereField("sharedReminderId", isEqualTo: sharedReminderId)
                .getDocuments { [weak self] snapshot, error in
                    guard let self = self else { return }

                    if let error = error {
                        #if DEBUG
                        print("ReminderViewModel: Error finding linked reminders: \(error.localizedDescription)")
                        #endif
                        // Fall back to deleting just this reminder
                        self.deleteSingleReminder(reminder.id)
                        return
                    }

                    guard let documents = snapshot?.documents, !documents.isEmpty else {
                        // No linked reminders found, delete just this one
                        self.deleteSingleReminder(reminder.id)
                        return
                    }

                    // Batch delete all linked reminders
                    let batch = self.db.batch()
                    for doc in documents {
                        batch.deleteDocument(doc.reference)
                    }

                    batch.commit { [weak self] error in
                        DispatchQueue.main.async {
                            if let error = error {
                                #if DEBUG
                                print("ReminderViewModel: Error syncing deletion: \(error.localizedDescription)")
                                #endif
                                self?.errorMessage = "Failed to delete shared reminders: \(error.localizedDescription)"
                            } else {
                                #if DEBUG
                                print("ReminderViewModel: Synced deletion across \(documents.count) linked reminders")
                                #endif
                            }
                        }
                    }
                }
        } else {
            // No sharing, just delete this reminder
            deleteSingleReminder(reminder.id)
        }
    }

    private func deleteSingleReminder(_ reminderId: String) {
        db.collection("reminders").document(reminderId).delete { [weak self] error in
            DispatchQueue.main.async {
                if let error = error {
                    #if DEBUG
                    print("ReminderViewModel: Error deleting reminder: \(error.localizedDescription)")
                    #endif
                    self?.errorMessage = "Failed to delete reminder: \(error.localizedDescription)"
                } else {
                    #if DEBUG
                    print("ReminderViewModel: Reminder deleted successfully")
                    #endif
                }
            }
        }
    }

    /// Delete a photo from a reminder by removing it from Storage and Firestore
    func deletePhoto(for reminder: Reminder, photoURL: String) {
        // Remove from Firebase Storage
        let storageRef = Storage.storage().reference(forURL: photoURL)
        storageRef.delete { [weak self] error in
            if let error = error {
                #if DEBUG
                print("ReminderViewModel: Error deleting photo from storage: \(error.localizedDescription)")
                #endif
                DispatchQueue.main.async {
                    self?.errorMessage = "Failed to delete photo: \(error.localizedDescription)"
                }
            } else {
                #if DEBUG
                print("ReminderViewModel: Photo deleted from storage")
                #endif
            }
        }

        // Remove URL from the Firestore array
        var currentURLs = reminder.photoURLs ?? []
        currentURLs.removeAll { $0 == photoURL }

        db.collection("reminders").document(reminder.id).updateData([
            "photoURLs": currentURLs
        ]) { [weak self] error in
            if let error = error {
                #if DEBUG
                print("ReminderViewModel: Error updating photoURLs: \(error.localizedDescription)")
                #endif
                DispatchQueue.main.async {
                    self?.errorMessage = "Failed to remove photo from reminder: \(error.localizedDescription)"
                }
            } else {
                #if DEBUG
                print("ReminderViewModel: Photo URL removed from reminder")
                #endif
            }
        }
    }

    // MARK: - Autosave

    /// The Firestore document ID of the currently autosaved (in-progress) reminder, if any
    var autosavedReminderId: String?

    /// Create or update an autosaved reminder as the user types.
    /// If no autosaved reminder exists yet, creates a new document. Otherwise updates the title of the existing one.
    func autosaveReminder(userStoreId: String, title: String, sharedWith: [String]? = nil, sharedFromName: String? = nil, currentUserName: String? = nil) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        guard !trimmedTitle.isEmpty else {
            discardAutosave()
            return
        }

        if let existingId = autosavedReminderId {
            // Update existing autosaved reminder's title
            db.collection("reminders").document(existingId).updateData([
                "title": trimmedTitle
            ]) { error in
                #if DEBUG
                if let error = error {
                    print("ReminderViewModel: Error updating autosaved reminder: \(error.localizedDescription)")
                }
                #endif
            }
        } else {
            // Create a new autosaved reminder
            let nextSortOrder = (reminders.compactMap { $0.sortOrder }.max() ?? -1) + 1

            var reminderData: [String: Any] = [
                "userStoreId": userStoreId,
                "title": trimmedTitle,
                "isDone": false,
                "createdAt": Date().timeIntervalSince1970,
                "sortOrder": nextSortOrder
            ]

            let isSharedStore = (sharedWith != nil && !sharedWith!.isEmpty) || sharedFromName != nil
            if isSharedStore {
                reminderData["isShared"] = true
                reminderData["sharedAt"] = Date().timeIntervalSince1970
                if let sharedWith = sharedWith, !sharedWith.isEmpty {
                    reminderData["sharedWith"] = sharedWith
                } else if let sharedFromName = sharedFromName {
                    reminderData["sharedWith"] = [sharedFromName]
                    if let currentUserName = currentUserName {
                        reminderData["sharedFrom"] = currentUserName
                    }
                }
            }

            let docRef = db.collection("reminders").document()
            autosavedReminderId = docRef.documentID

            docRef.setData(reminderData) { [weak self] error in
                if let error = error {
                    #if DEBUG
                    print("ReminderViewModel: Error creating autosaved reminder: \(error.localizedDescription)")
                    #endif
                    DispatchQueue.main.async {
                        self?.autosavedReminderId = nil
                    }
                } else {
                    #if DEBUG
                    print("ReminderViewModel: Autosaved reminder created with ID: \(docRef.documentID)")
                    #endif
                }
            }
        }
    }

    /// Finalize the autosaved reminder: update to the final title and trigger AI categorization.
    /// Called when the user presses Return or navigates away with text entered.
    func finalizeAutosave(userStoreId: String, finalTitle: String) {
        guard let reminderId = autosavedReminderId else { return }

        let trimmedTitle = finalTitle.trimmingCharacters(in: .whitespaces)
        guard !trimmedTitle.isEmpty else {
            discardAutosave()
            return
        }

        // Update to the final title
        db.collection("reminders").document(reminderId).updateData([
            "title": trimmedTitle
        ]) { error in
            #if DEBUG
            if let error = error {
                print("ReminderViewModel: Error finalizing autosaved reminder title: \(error.localizedDescription)")
            }
            #endif
        }

        autosavedReminderId = nil

        // Trigger AI categorization after snapshot listener picks up the reminder
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            if let reminder = self.reminders.first(where: { $0.id == reminderId && $0.category == nil }) {
                self.categorizeReminder(reminder)
            }
        }
    }

    /// Discard (delete) the autosaved reminder from Firestore
    func discardAutosave() {
        guard let reminderId = autosavedReminderId else { return }
        autosavedReminderId = nil
        deleteSingleReminder(reminderId)
    }

    /// Upload a photo for a reminder and append its URL to the reminder's photoURLs array
    func uploadPhoto(for reminder: Reminder, image: UIImage) {
        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            #if DEBUG
            print("ReminderViewModel: Failed to convert image to JPEG data")
            #endif
            DispatchQueue.main.async {
                self.errorMessage = "Failed to process image for upload"
            }
            return
        }

        let photoId = UUID().uuidString
        let storageRef = Storage.storage().reference()
        let photoRef = storageRef.child("reminder_photos/\(reminder.id)/\(photoId).jpg")

        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        photoRef.putData(imageData, metadata: metadata) { [weak self] _, error in
            guard let self = self else { return }

            if let error = error {
                #if DEBUG
                print("ReminderViewModel: Error uploading photo: \(error.localizedDescription)")
                #endif
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to upload photo: \(error.localizedDescription)"
                }
                return
            }

            photoRef.downloadURL { [weak self] url, error in
                if let error = error {
                    #if DEBUG
                    print("ReminderViewModel: Error getting download URL: \(error.localizedDescription)")
                    #endif
                    DispatchQueue.main.async {
                        self?.errorMessage = "Failed to upload photo: \(error.localizedDescription)"
                    }
                    return
                }

                guard let downloadURL = url?.absoluteString else { return }

                // Append the new photo URL to the existing array
                var currentURLs = reminder.photoURLs ?? []
                currentURLs.append(downloadURL)

                self?.db.collection("reminders").document(reminder.id).updateData([
                    "photoURLs": currentURLs
                ]) { error in
                    if let error = error {
                        #if DEBUG
                        print("ReminderViewModel: Error saving photo URL: \(error.localizedDescription)")
                        #endif
                        DispatchQueue.main.async {
                            self?.errorMessage = "Failed to save photo: \(error.localizedDescription)"
                        }
                    } else {
                        #if DEBUG
                        print("ReminderViewModel: Photo uploaded and URL saved successfully")
                        #endif
                    }
                }
            }
        }
    }
}
