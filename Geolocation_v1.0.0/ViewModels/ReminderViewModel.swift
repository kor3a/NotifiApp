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
    /// userId → display name resolved from the user's friends, used to show the
    /// correct author avatar/initial for shared reminders that carry an author
    /// id but no `sharedFrom` name (e.g. copies synced without it).
    @Published var authorNamesById: [String: String] = [:]
    /// Guards against overlapping/repeated friend fetches for name resolution.
    private var isResolvingAuthorNames = false
    /// Author ids we've already tried to resolve, so an id that isn't among the
    /// user's friends doesn't trigger a fetch on every snapshot.
    private var attemptedAuthorIds: Set<String> = []
    /// Reminder IDs that are staged for deletion (hidden from display, pending undo window)
    @Published var stagedForDeletion: Set<String> = []
    /// Flag to prevent snapshot listener from overwriting local state during a reorder operation
    private var isReordering = false

    // MARK: - Change Tracking for Shared Store Notifications

    /// Number of reminders added during this editing session (for shared store notifications)
    private(set) var pendingAdditions: Int = 0
    /// Number of other changes (edits, deletes, toggles) during this editing session
    private(set) var pendingOtherChanges: Int = 0
    /// Whether any tracked changes have been made since the last reset
    var hasPendingChanges: Bool { pendingAdditions > 0 || pendingOtherChanges > 0 }

    /// Reset change counters (call after sending notifications)
    func resetPendingChanges() {
        pendingAdditions = 0
        pendingOtherChanges = 0
    }

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
                        let sharedFromId = data["sharedFromId"] as? String
                        let sharedAt = data["sharedAt"] as? TimeInterval
                        let sharedReminderId = data["sharedReminderId"] as? String
                        let sharedWith = data["sharedWith"] as? [String]

                        // If viewing a shared store and reminder is shared but has no sharedFrom,
                        // populate it with the store owner's name so the badge shows the correct
                        // direction (received-from arrow) for the recipient.
                        //
                        // Skip when sharedWith is set AND the current user's name is NOT in it —
                        // that means this user created/shared the reminder outward (e.g. a merge
                        // recipient's own items), so sharedFrom should stay nil and the badge
                        // will correctly show the "sharing to" arrow.
                        if isShared == true && sharedFrom == nil && sharedFromName != nil {
                            let currentUserName = UserSessionManager.shared.currentUser?.name
                            let currentUserIsInSharedWith = sharedWith?.contains(where: {
                                $0.lowercased() == currentUserName?.lowercased() ?? ""
                            }) ?? false
                            if sharedWith == nil || currentUserIsInSharedWith {
                                sharedFrom = sharedFromName
                            }
                        }

                        let photoURLs = data["photoURLs"] as? [String]
                        let sortOrder = data["sortOrder"] as? Int
                        let quantity = data["quantity"] as? Int
                        let isOutOfStock = data["isOutOfStock"] as? Bool
                        let category = data["category"] as? String
                        let checkedOffAt = data["checkedOffAt"] as? TimeInterval
                        let checkedOffBy = data["checkedOffBy"] as? String
                        let checkedOffById = data["checkedOffById"] as? String
                        let lastEditedAt = data["lastEditedAt"] as? TimeInterval
                        let lastEditedBy = data["lastEditedBy"] as? String
                        let lastEditedById = data["lastEditedById"] as? String

                        return Reminder(
                            id: doc.documentID,
                            userStoreId: userStoreId,
                            title: title,
                            isDone: isDone,
                            createdAt: createdAt,
                            isShared: isShared,
                            sharedFrom: sharedFrom,
                            sharedFromId: sharedFromId,
                            sharedAt: sharedAt,
                            sharedReminderId: sharedReminderId,
                            sharedWith: sharedWith,
                            photoURLs: photoURLs,
                            sortOrder: sortOrder,
                            quantity: quantity,
                            isOutOfStock: isOutOfStock,
                            category: category,
                            checkedOffAt: checkedOffAt,
                            checkedOffBy: checkedOffBy,
                            checkedOffById: checkedOffById,
                            lastEditedAt: lastEditedAt,
                            lastEditedBy: lastEditedBy,
                            lastEditedById: lastEditedById
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

                    // Remove orphaned staged photo URLs — once Firestore confirms a photo
                    // is deleted its URL is absent from all reminders, so the entry is stale.
                    if !self.stagedPhotoUrls.isEmpty {
                        let allPhotoURLs = Set(fetchedReminders.flatMap { $0.photoURLs ?? [] })
                        self.stagedPhotoUrls = self.stagedPhotoUrls.intersection(allPhotoURLs)
                    }

                    #if DEBUG
                    print("ReminderViewModel: Successfully loaded \(self.reminders.count) reminders")
                    #endif

                    // Recover author names for shared items that carry an author
                    // id but no name, so their avatar shows the real initial.
                    self.resolveMissingAuthorNames()
                }
            }
    }

    /// Resolves display names for shared reminders that carry a participant id
    /// (`sharedFromId` for the author, `lastEditedById` for whoever last edited
    /// it) but no matching name, so their avatar shows the real initial instead
    /// of a neutral icon. Names come from the user's friends list — which is
    /// readable and kept current on name changes — rather than reading other
    /// users' documents directly (blocked by rules).
    private func resolveMissingAuthorNames() {
        guard !isResolvingAuthorNames,
              let currentUserId = UserSessionManager.shared.currentUser?.userId else { return }

        // Collect participant ids that still need a name and we haven't tried
        // yet. The avatar names the item's last editor when it has one and its
        // author otherwise, so both need a name to render.
        let idsNeedingName = Set(reminders.flatMap { reminder -> [String] in
            guard reminder.isShared == true else { return [] }
            let participants = [
                (reminder.sharedFromId, reminder.sharedFrom),
                (reminder.lastEditedById, reminder.lastEditedBy)
            ]
            return participants.compactMap { participant -> String? in
                let (id, name) = participant
                guard let id = id, !id.isEmpty, id != currentUserId else { return nil }
                let hasName = !(name?.isEmpty ?? true)
                guard !hasName, authorNamesById[id] == nil,
                      !attemptedAuthorIds.contains(id) else { return nil }
                return id
            }
        })
        guard !idsNeedingName.isEmpty else { return }

        isResolvingAuthorNames = true
        attemptedAuthorIds.formUnion(idsNeedingName)
        FriendRequestService.shared.getFriends(userId: currentUserId) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isResolvingAuthorNames = false
                if case .success(let friends) = result {
                    for friend in friends where !friend.name.isEmpty {
                        self.authorNamesById[friend.id] = friend.name
                    }
                }
            }
        }
    }

    // MARK: - Category Grouping

    /// All distinct categories present in the current reminders, in the order
    /// their first item appears. Sections are therefore ordered by the same
    /// persisted `sortOrder` that orders the rows within them, which is what
    /// lets a category be dragged to a new position (see `moveCategory`).
    var categoryOrder: [String] {
        orderedCategories(in: reminders)
    }

    /// Reminders grouped by category. Key is the display category name.
    func reminders(for category: String) -> [Reminder] {
        if category == Self.uncategorizedCategoryName {
            return reminders.filter { $0.category == nil || $0.category?.isEmpty == true }
        }
        return reminders.filter { $0.category == category }
    }

    /// Whether we should display reminders in category sections (true when at least one reminder has a category)
    var hasCategorizedReminders: Bool {
        reminders.contains { $0.category != nil && $0.category?.isEmpty == false }
    }

    // MARK: - Display-Filtered Reminders (excludes in-progress autosave)

    /// Reminders excluding the currently autosaved (in-progress) one, for display in the list.
    /// The autosaved reminder is hidden while the user is still typing in the inline add field.
    var displayedReminders: [Reminder] {
        reminders.filter { $0.id != autosavedReminderId && !stagedForDeletion.contains($0.id) }
    }

    /// Displayed category order (excludes autosaved reminder)
    var displayedCategoryOrder: [String] {
        orderedCategories(in: displayedReminders)
    }

    /// Displayed reminders for a given category (excludes autosaved reminder)
    func displayedReminders(for category: String) -> [Reminder] {
        let base = displayedReminders
        if category == Self.uncategorizedCategoryName {
            return base.filter { $0.category == nil || $0.category?.isEmpty == true }
        }
        return base.filter { $0.category == category }
    }

    /// Whether displayed reminders have categories (excludes autosaved reminder)
    var hasDisplayedCategorizedReminders: Bool {
        displayedReminders.contains { $0.category != nil && $0.category?.isEmpty == false }
    }

    // MARK: - AI Categorization

    /// Max item titles sent to the model in one categorization request. The reply
    /// is a JSON map bounded by `maxTokens`, so a whole backlog in a single call
    /// risks a truncated (and therefore discarded) response.
    private static let categorizationBatchSize = 20

    /// Reminder IDs already handed to the AI in this session. Items the model
    /// genuinely can't place come back "Uncategorized" and keep a nil category,
    /// so without this they'd be re-sent on every snapshot for as long as the
    /// view is open. Also keeps the bulk pass from duplicating work the
    /// single-item path is already doing for a just-added reminder.
    private var aiCategorizationAttemptedIds: Set<String> = []

    /// True while a bulk categorization pass is in flight, so overlapping
    /// triggers (snapshots landing, subscription activating, view re-appearing)
    /// coalesce into one pass.
    @Published private(set) var isCategorizingBacklog = false

    /// Categorize a single reminder using AI and update Firestore
    func categorizeReminder(_ reminder: Reminder) {
        aiCategorizationAttemptedIds.insert(reminder.id)
        Task {
            do {
                let mapping = try await OpenAIService.shared.categorizeItems([reminder.title])
                let category = mapping[reminder.title] ?? "Uncategorized"
                await MainActor.run {
                    self.updateReminderCategory(
                        reminder,
                        newCategory: category == "Uncategorized" ? nil : category,
                        tracksChange: false
                    )
                }
            } catch {
                #if DEBUG
                print("ReminderViewModel: AI categorization failed for '\(reminder.title)': \(error.localizedDescription)")
                #endif
                // Leave category as nil — user can set it manually
                await MainActor.run {
                    self.aiCategorizationAttemptedIds.remove(reminder.id)
                }
            }
        }
    }

    /// Categorize every uncategorized reminder in the current store that hasn't
    /// already been sent to the AI.
    ///
    /// Backfills lists built up while Smart Category was unavailable — items
    /// added without a subscription stay uncategorized, and this fills them in
    /// once the user has access. Safe to call repeatedly: in-flight passes and
    /// already-attempted items are skipped, so nothing is billed twice.
    func categorizeUncategorizedReminders() {
        guard !isCategorizingBacklog else { return }

        let uncategorized = reminders.filter { reminder in
            (reminder.category?.isEmpty ?? true)
                && reminder.id != autosavedReminderId
                && !stagedForDeletion.contains(reminder.id)
                && !aiCategorizationAttemptedIds.contains(reminder.id)
                && !reminder.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        guard !uncategorized.isEmpty else { return }

        aiCategorizationAttemptedIds.formUnion(uncategorized.map { $0.id })
        isCategorizingBacklog = true

        #if DEBUG
        print("ReminderViewModel: Backfilling categories for \(uncategorized.count) reminders")
        #endif

        Task { [weak self] in
            guard let self = self else { return }
            await self.categorizeInBatches(uncategorized)
            await MainActor.run { self.isCategorizingBacklog = false }
        }
    }

    /// Categorize reminders in chunks, writing each chunk's results as they land
    /// so a long list fills in progressively instead of all at the very end.
    private func categorizeInBatches(_ targets: [Reminder]) async {
        for start in stride(from: 0, to: targets.count, by: Self.categorizationBatchSize) {
            let chunk = Array(targets[start..<min(start + Self.categorizationBatchSize, targets.count)])
            do {
                let mapping = try await OpenAIService.shared.categorizeItems(chunk.map { $0.title })
                await MainActor.run {
                    for reminder in chunk {
                        guard let category = mapping[reminder.title],
                              category != "Uncategorized",
                              !category.isEmpty else { continue }
                        // Not a user edit, so it must not count toward the
                        // "someone changed the list" shared-store notification.
                        self.updateReminderCategory(reminder, newCategory: category, tracksChange: false)
                    }
                }
            } catch {
                #if DEBUG
                print("ReminderViewModel: Bulk AI categorization failed: \(error.localizedDescription)")
                #endif
                // Let this chunk be retried the next time a pass is triggered.
                await MainActor.run {
                    self.aiCategorizationAttemptedIds.subtract(chunk.map { $0.id })
                }
            }
        }
    }

    /// Update a reminder's category — syncs across all linked shared reminders
    /// - Parameter tracksChange: whether this counts as a user edit for the
    ///   shared-store change notification. AI categorization passes `false`;
    ///   backfilling a long list is not something to notify the other members about.
    func updateReminderCategory(_ reminder: Reminder, newCategory: String?, tracksChange: Bool = true) {
        #if DEBUG
        print("ReminderViewModel: Updating category for '\(reminder.title)' to '\(newCategory ?? "nil")'")
        #endif

        if tracksChange {
            pendingOtherChanges += 1
        }
        let fieldValue: Any = newCategory ?? FieldValue.delete()
        // A user re-categorizing an item is an edit, so it re-attributes the
        // row's avatar to them. AI backfill (tracksChange: false) is not — it
        // must leave the existing attribution alone.
        var updateFields: [String: Any] = ["category": fieldValue]
        if tracksChange {
            updateFields = ReminderEditAttribution.stamped(updateFields)
        }

        if let sharedReminderId = reminder.sharedReminderId {
            db.collection("reminders")
                .whereField("sharedReminderId", isEqualTo: sharedReminderId)
                .getDocuments { [weak self] snapshot, error in
                    guard let self = self else { return }

                    if let error = error {
                        #if DEBUG
                        print("ReminderViewModel: Error finding linked reminders for category update: \(error.localizedDescription)")
                        #endif
                        self.updateSingleReminderCategory(reminder.id, fields: updateFields)
                        return
                    }

                    guard let documents = snapshot?.documents, !documents.isEmpty else {
                        self.updateSingleReminderCategory(reminder.id, fields: updateFields)
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
            updateSingleReminderCategory(reminder.id, fields: updateFields)
        }
    }

    private func updateSingleReminderCategory(_ reminderId: String, fields: [String: Any]) {
        db.collection("reminders").document(reminderId).updateData(fields) { error in
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

    /// Fetch favorite tags for a specific user_store (real-time listener).
    /// Only returns tags belonging to the current user — favorites are private per user.
    func fetchFavoriteTags(for userStoreId: String) {
        favoriteTagsListener?.remove()

        guard let currentUserId = UserSessionManager.shared.currentUser?.userId else {
            favoriteTags = []
            return
        }

        favoriteTagsListener = db.collection("favorite_tags")
            .whereField("userStoreId", isEqualTo: userStoreId)
            .whereField("userId", isEqualTo: currentUserId)
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
                              let userId = data["userId"] as? String,
                              let title = data["title"] as? String,
                              let createdAt = data["createdAt"] as? TimeInterval else {
                            return nil
                        }
                        return FavoriteTag(
                            id: doc.documentID,
                            userStoreId: userStoreId,
                            userId: userId,
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
            "userId": UserSessionManager.shared.currentUser?.userId ?? "",
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

    func removeAllFavoriteTags() {
        let batch = db.batch()
        for tag in favoriteTags {
            let ref = db.collection("favorite_tags").document(tag.id)
            batch.deleteDocument(ref)
        }
        batch.commit { error in
            if let error = error {
                #if DEBUG
                print("ReminderViewModel: Error removing all favorite tags: \(error.localizedDescription)")
                #endif
            } else {
                #if DEBUG
                print("ReminderViewModel: All favorite tags removed successfully")
                #endif
            }
        }
    }

    /// Add a reminder from a favorite tag tap (only if a reminder with that title doesn't already exist)
    func addReminderFromFavorite(tag: FavoriteTag, sharedWith: [String]? = nil, sharedFromName: String? = nil, currentUserName: String? = nil, useSmartCategory: Bool = true) {
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
            currentUserName: currentUserName,
            useSmartCategory: useSmartCategory
        )
    }

    /// Add a new reminder
    /// - Parameters:
    ///   - userStoreId: The user_store ID to add the reminder to
    ///   - title: The reminder title
    ///   - sharedWith: If the store is shared (owner's perspective), the names of users it's shared with
    ///   - sharedFromName: If the store is shared (recipient's perspective), the name of the owner who shared the store
    ///   - currentUserName: The name of the user adding the reminder (for tracking who created it in shared stores)
    ///   - quantity: Optional starting quantity, written with the document so callers
    ///     that already know the count (e.g. a voice command) don't need a follow-up update
    func addReminder(userStoreId: String, title: String, sharedWith: [String]? = nil, sharedFromName: String? = nil, currentUserName: String? = nil, useSmartCategory: Bool = true, quantity: Int? = nil) {
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

        if let quantity = quantity, quantity > 1 {
            reminderData["quantity"] = quantity
        }

        // Check if this is a shared store (either owner or recipient perspective)
        let isSharedStore = (sharedWith != nil && !sharedWith!.isEmpty) || sharedFromName != nil

        if isSharedStore {
            reminderData["isShared"] = true
            reminderData["sharedAt"] = Date().timeIntervalSince1970

            // Check the recipient perspective first. sharedFromName is set
            // whenever the current user received this store from someone else,
            // even in the merge flow where their own user_store.sharedWith also
            // contains the owner's name. Without this ordering a merge recipient
            // would fall through to the owner branch and lose attribution.
            if let sharedFromName = sharedFromName {
                // Recipient adding: record the reminder as shared back to the owner
                reminderData["sharedWith"] = [sharedFromName]
            } else if let sharedWith = sharedWith, !sharedWith.isEmpty {
                // Owner adding: use their full recipient list
                reminderData["sharedWith"] = sharedWith
            }

            // Always attribute the reminder to whoever created it. Persisting
            // this on the document avoids relying on retroactive backfill from
            // the store's sharedFromName (which breaks if the cached name is
            // stale, missing, or doesn't match the viewer's display name).
            if let currentUserName = currentUserName {
                reminderData["sharedFrom"] = currentUserName
            }
            if let currentUserId = UserSessionManager.shared.currentUser?.userId {
                reminderData["sharedFromId"] = currentUserId
            }
        }

        // Track addition synchronously so the count is available immediately
        // (before the user can navigate away)
        pendingAdditions += 1

        db.collection("reminders").addDocument(data: reminderData) { [weak self] error in
            DispatchQueue.main.async {
                if let error = error {
                    #if DEBUG
                    print("ReminderViewModel: Error adding reminder: \(error.localizedDescription)")
                    #endif
                    self?.errorMessage = "Error adding reminder: \(error.localizedDescription)"
                    // Undo the synchronous increment since the add failed
                    self?.pendingAdditions = max(0, (self?.pendingAdditions ?? 1) - 1)
                } else {
                    #if DEBUG
                    print("ReminderViewModel: Reminder added successfully (isShared: \(isSharedStore))")
                    #endif
                    // Trigger AI categorization for the newly added reminder once it appears
                    // in the snapshot listener results (only when Smart Category is enabled)
                    if useSmartCategory {
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

    // MARK: - Drag Reordering (categories and items)

    /// Display name for items that carry no category of their own.
    static let uncategorizedCategoryName = "Uncategorized"

    /// The section a reminder belongs to.
    func categoryName(for reminder: Reminder) -> String {
        if let category = reminder.category, !category.isEmpty { return category }
        return Self.uncategorizedCategoryName
    }

    /// Section order for a list of reminders: the order their categories first
    /// appear. Because `reminders` is kept sorted by `sortOrder`, this makes the
    /// section order a function of the same persisted field that orders the rows
    /// inside a section — dragging a category is just a renumbering, and it
    /// syncs to every device and shared-list member for free.
    private func orderedCategories(in list: [Reminder]) -> [String] {
        var seen = Set<String>()
        var order: [String] = []
        for reminder in list {
            let name = categoryName(for: reminder)
            if seen.insert(name).inserted {
                order.append(name)
            }
        }
        return order
    }

    /// Snapshot of `reminders` taken when a drag lifts off. Hover moves
    /// rearrange `reminders` in place so the list animates under the finger;
    /// this is what the drop diffs against, and what an abandoned drag restores.
    private var dragBaseline: [Reminder]?

    /// Fires if a lifted drag never reaches a drop target (dropped outside the
    /// app, cancelled by a call), so the paused snapshot listener can't stay
    /// paused and freeze the list.
    private var dragWatchdog: DispatchWorkItem?

    /// True while a category or row is in flight. Published so the view can drop
    /// its own drag state when the watchdog cancels a drag it never saw end.
    @Published private(set) var isDragging = false

    func beginDrag() {
        guard dragBaseline == nil else { return }
        dragBaseline = reminders
        isDragging = true
        // Hold snapshot rebuilds so a listener callback mid-drag can't yank the
        // rows out from under the finger.
        isReordering = true
        armDragWatchdog()
    }

    /// Restore the pre-drag order and let snapshots through again.
    func cancelDrag() {
        guard let baseline = dragBaseline else { return }
        dragWatchdog?.cancel()
        dragWatchdog = nil
        reminders = baseline
        dragBaseline = nil
        isDragging = false
        isReordering = false
    }

    private func armDragWatchdog() {
        dragWatchdog?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.cancelDrag() }
        dragWatchdog = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 20, execute: work)
    }

    /// Move a whole category — header and every item under it — into the
    /// position `target` currently occupies. Local only; `commitDrag()` persists.
    func moveCategory(_ category: String, before target: String) {
        guard category != target else { return }
        var order = orderedCategories(in: reminders)
        guard let from = order.firstIndex(of: category),
              let to = order.firstIndex(of: target) else { return }
        order.remove(at: from)
        order.insert(category, at: to)
        reminders = regrouped(reminders, byCategoryOrder: order)
        armDragWatchdog()
    }

    /// Move a dragged item to `target`'s position, adopting `target`'s category
    /// when they differ. `placeAfter` puts it below the target rather than above,
    /// which is what makes the bottom of a section reachable. Local only;
    /// `commitDrag()` persists.
    func moveReminder(id: String, onto target: Reminder, placeAfter: Bool = false) {
        guard id != target.id,
              let from = reminders.firstIndex(where: { $0.id == id }) else { return }
        var updated = reminders
        var moved = updated.remove(at: from)
        moved.category = target.category
        var to = updated.firstIndex(where: { $0.id == target.id }) ?? updated.count
        if placeAfter, to < updated.count { to += 1 }
        updated.insert(moved, at: to)
        reminders = regrouped(updated, byCategoryOrder: orderedCategories(in: updated))
        armDragWatchdog()
    }

    /// Move a dragged item to the top of `category`. This is the drop that lands
    /// on a section header, so it also works for a collapsed section that shows
    /// no rows to aim at. Local only; `commitDrag()` persists.
    func moveReminder(id: String, toCategory category: String) {
        guard let from = reminders.firstIndex(where: { $0.id == id }),
              categoryName(for: reminders[from]) != category else { return }
        var updated = reminders
        var moved = updated.remove(at: from)
        moved.category = (category == Self.uncategorizedCategoryName) ? nil : category
        if let first = updated.firstIndex(where: { categoryName(for: $0) == category }) {
            updated.insert(moved, at: first)
        } else {
            updated.append(moved)
        }
        reminders = regrouped(updated, byCategoryOrder: orderedCategories(in: updated))
        armDragWatchdog()
    }

    /// Reorders `list` so every category's items sit together in `order`, each
    /// section keeping its internal order. Legacy lists can have a category's
    /// items scattered across the global order; this makes the flat array match
    /// what the sectioned list actually shows, so the sort orders written on
    /// drop describe that same arrangement.
    private func regrouped(_ list: [Reminder], byCategoryOrder order: [String]) -> [Reminder] {
        var buckets: [String: [Reminder]] = [:]
        for reminder in list {
            buckets[categoryName(for: reminder), default: []].append(reminder)
        }
        return order.flatMap { buckets[$0] ?? [] }
    }

    /// Persist what the drag rearranged: a new `sortOrder` for every row that
    /// moved, plus a category change for any item dragged into another section.
    func commitDrag() {
        guard let baseline = dragBaseline else { return }
        dragWatchdog?.cancel()
        dragWatchdog = nil
        dragBaseline = nil
        isDragging = false

        let before = Dictionary(baseline.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        // Category changes go through the normal path so linked copies on a
        // shared list follow along and the edit is attributed to this user.
        var categoryChanges: [(reminder: Reminder, newCategory: String?)] = []
        for reminder in reminders {
            guard let old = before[reminder.id], old.category != reminder.category else { continue }
            categoryChanges.append((old, reminder.category))
        }

        let batch = db.batch()
        var hasSortChanges = false
        var renumbered = reminders
        for index in renumbered.indices where renumbered[index].sortOrder != index {
            renumbered[index].sortOrder = index
            hasSortChanges = true
            batch.updateData(
                ["sortOrder": index],
                forDocument: db.collection("reminders").document(renumbered[index].id)
            )
        }
        if hasSortChanges {
            reminders = renumbered
        }

        for (reminder, newCategory) in categoryChanges {
            updateReminderCategory(reminder, newCategory: newCategory)
        }

        guard hasSortChanges else {
            isReordering = false
            return
        }

        batch.commit { [weak self] error in
            DispatchQueue.main.async {
                self?.isReordering = false
                if let error = error {
                    #if DEBUG
                    print("ReminderViewModel: Error persisting drag order: \(error.localizedDescription)")
                    #endif
                    self?.errorMessage = "Failed to update sort order: \(error.localizedDescription)"
                } else {
                    #if DEBUG
                    print("ReminderViewModel: Drag order persisted")
                    #endif
                }
            }
        }
    }

    /// Move a reminder to a different store by updating its userStoreId in Firestore
    func moveReminderToStore(_ reminder: Reminder, targetStore: UserStoreItem) {
        let targetUserStoreId = targetStore.reminderStoreId
        #if DEBUG
        print("ReminderViewModel: Moving reminder '\(reminder.title)' to store \(targetUserStoreId)")
        #endif

        // Determine if the target store has an active sharing relationship.
        // A store is actively shared when it has accepted recipients (sharedWith non-empty),
        // or the current user is a recipient themselves (sourceUserStoreId / sharedStoreGroupId set).
        let targetIsActivelyShared = (targetStore.sharedWith != nil && !targetStore.sharedWith!.isEmpty)
            || targetStore.sourceUserStoreId != nil
            || targetStore.sharedStoreGroupId != nil

        var updateData: [String: Any] = ["userStoreId": targetUserStoreId]

        // If the target store has no active sharing, strip all sharing metadata so the
        // reminder no longer shows the shared icon or stale sharing info.
        if !targetIsActivelyShared {
            updateData["isShared"] = FieldValue.delete()
            updateData["sharedWith"] = FieldValue.delete()
            updateData["sharedFrom"] = FieldValue.delete()
            updateData["sharedFromId"] = FieldValue.delete()
            updateData["sharedAt"] = FieldValue.delete()
            updateData["sharedReminderId"] = FieldValue.delete()
            // Drop the edit attribution too, so if this item is ever shared
            // again its avatar starts from its new author rather than whoever
            // last edited it back when it was shared.
            updateData["lastEditedAt"] = FieldValue.delete()
            updateData["lastEditedBy"] = FieldValue.delete()
            updateData["lastEditedById"] = FieldValue.delete()
        }

        db.collection("reminders").document(reminder.id).updateData(updateData) { error in
            if let error = error {
                #if DEBUG
                print("ReminderViewModel: Error moving reminder to store: \(error.localizedDescription)")
                #endif
            } else {
                #if DEBUG
                print("ReminderViewModel: Reminder moved successfully")
                #endif
            }
        }
    }

    /// Toggle reminder isDone status - syncs across all linked shared reminders
    /// Also clears isOutOfStock when toggling isDone on
    func toggleReminder(_ reminder: Reminder) {
        #if DEBUG
        print("ReminderViewModel: Toggling reminder '\(reminder.title)'")
        #endif

        pendingOtherChanges += 1

        // ReminderToggleService owns the field bookkeeping and the fan-out to
        // linked copies of a shared reminder.
        let fields = ReminderToggleService.toggleFields(
            newIsDone: !reminder.isDone,
            wasOutOfStock: reminder.isOutOfStock == true
        )

        ReminderToggleService.apply(
            fields: fields,
            reminderId: reminder.id,
            sharedReminderId: reminder.sharedReminderId,
            db: db
        )
    }

    /// Toggle reminder out-of-stock status - syncs across all linked shared reminders
    /// When marking as out of stock, also clears isDone. When clearing out of stock, leaves isDone as false.
    func toggleOutOfStock(_ reminder: Reminder) {
        #if DEBUG
        print("ReminderViewModel: Toggling out-of-stock for reminder '\(reminder.title)'")
        #endif

        pendingOtherChanges += 1

        let newOutOfStock = !(reminder.isOutOfStock ?? false)
        var updateFields: [String: Any] = ["isOutOfStock": newOutOfStock]

        // When marking as out of stock, ensure isDone is false
        if newOutOfStock {
            updateFields["isDone"] = false
        }

        // Flagging an item unavailable changes the item itself, so the row's
        // avatar follows the member who flagged it.
        updateFields = ReminderEditAttribution.stamped(updateFields)

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

        pendingOtherChanges += 1
        #if DEBUG
        print("ReminderViewModel: Updating title for reminder '\(reminder.title)' to '\(trimmedTitle)'")
        #endif

        // Re-attribute the row to whoever renamed it, on every linked copy.
        let updateFields = ReminderEditAttribution.stamped(["title": trimmedTitle])

        if let sharedReminderId = reminder.sharedReminderId {
            db.collection("reminders")
                .whereField("sharedReminderId", isEqualTo: sharedReminderId)
                .getDocuments { [weak self] snapshot, error in
                    guard let self = self else { return }

                    if let error = error {
                        #if DEBUG
                        print("ReminderViewModel: Error finding linked reminders for title update: \(error.localizedDescription)")
                        #endif
                        self.updateSingleReminderTitle(reminder.id, fields: updateFields)
                        return
                    }

                    guard let documents = snapshot?.documents, !documents.isEmpty else {
                        self.updateSingleReminderTitle(reminder.id, fields: updateFields)
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
            updateSingleReminderTitle(reminder.id, fields: updateFields)
        }
    }

    /// Update reminder quantity - syncs across all linked shared reminders
    /// Pass nil to remove the quantity
    func updateReminderQuantity(_ reminder: Reminder, newQuantity: Int?) {
        #if DEBUG
        print("ReminderViewModel: Updating quantity for reminder '\(reminder.title)' to \(newQuantity.map(String.init) ?? "nil")")
        #endif

        pendingOtherChanges += 1
        let fieldValue: Any = newQuantity ?? FieldValue.delete()
        // Changing how many to buy is an edit, so the row's avatar follows it.
        let updateFields = ReminderEditAttribution.stamped(["quantity": fieldValue])

        if let sharedReminderId = reminder.sharedReminderId {
            db.collection("reminders")
                .whereField("sharedReminderId", isEqualTo: sharedReminderId)
                .getDocuments { [weak self] snapshot, error in
                    guard let self = self else { return }

                    if let error = error {
                        #if DEBUG
                        print("ReminderViewModel: Error finding linked reminders for quantity update: \(error.localizedDescription)")
                        #endif
                        self.updateSingleReminderQuantity(reminder.id, fields: updateFields)
                        return
                    }

                    guard let documents = snapshot?.documents, !documents.isEmpty else {
                        self.updateSingleReminderQuantity(reminder.id, fields: updateFields)
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
            updateSingleReminderQuantity(reminder.id, fields: updateFields)
        }
    }

    private func updateSingleReminderQuantity(_ reminderId: String, fields: [String: Any]) {
        db.collection("reminders").document(reminderId).updateData(fields) { error in
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

    private func updateSingleReminderTitle(_ reminderId: String, fields: [String: Any]) {
        db.collection("reminders").document(reminderId).updateData(fields) { error in
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

    // MARK: - Undo Support (Staged Deletion)

    /// Stage a reminder for deletion — hides it from the list without touching Firestore.
    /// Call `commitStagedDeletion` to permanently delete or `undoStagedDeletion` to restore.
    func stageForDeletion(_ reminder: Reminder) {
        stagedForDeletion.insert(reminder.id)
    }

    /// Restore a staged reminder — removes it from the hidden set so it reappears in the list.
    func undoStagedDeletion(_ reminderId: String) {
        stagedForDeletion.remove(reminderId)
    }

    /// Permanently delete a staged reminder from Firestore.
    func commitStagedDeletion(_ reminder: Reminder) {
        stagedForDeletion.remove(reminder.id)
        deleteReminder(reminder)
    }

    // MARK: - Undo Support (Staged Photo Deletion)

    /// Photo URLs staged for deletion — hidden from the item view during the undo window.
    /// Entries are cleaned up automatically when the Firestore snapshot no longer contains them.
    @Published var stagedPhotoUrls: Set<String> = []

    /// Hide a photo URL locally without touching Firestore.
    func stagePhotoUrl(_ url: String) {
        stagedPhotoUrls.insert(url)
    }

    /// Restore a staged photo URL so it reappears in the item view.
    func unstagePhotoUrl(_ url: String) {
        stagedPhotoUrls.remove(url)
    }

    // MARK: - Check-off History

    /// Preserve a checked-off reminder in the `reminder_history` collection just
    /// before its document is deleted, so it stays visible in the store's
    /// HistoryView. `data` is the reminder document's Firestore data; `fallback`
    /// is the local copy, which is authoritative when the check-off never
    /// reached Firestore (the auto-delete flow deletes without toggling isDone).
    ///
    /// Static and bound only to the Firestore singleton so the write still
    /// happens if the ViewModel is deallocated mid-deletion (e.g. the user
    /// navigated away while the undo window was open).
    static func recordHistoryEntry(data: [String: Any], fallback: Reminder) {
        let now = Date().timeIntervalSince1970
        var entry: [String: Any] = [
            "userStoreId": (data["userStoreId"] as? String) ?? fallback.userStoreId,
            "title": (data["title"] as? String) ?? fallback.title,
            "checkedOffAt": (data["checkedOffAt"] as? TimeInterval) ?? fallback.checkedOffAt ?? now,
            "deletedAt": now
        ]
        entry["createdAt"] = (data["createdAt"] as? TimeInterval) ?? fallback.createdAt
        if let quantity = (data["quantity"] as? Int) ?? fallback.quantity {
            entry["quantity"] = quantity
        }
        if let photoURLs = (data["photoURLs"] as? [String]) ?? fallback.photoURLs, !photoURLs.isEmpty {
            entry["photoURLs"] = photoURLs
        }
        if let category = (data["category"] as? String) ?? fallback.category {
            entry["category"] = category
        }
        if let checkedOffBy = (data["checkedOffBy"] as? String) ?? fallback.checkedOffBy {
            entry["checkedOffBy"] = checkedOffBy
        }
        if let checkedOffById = (data["checkedOffById"] as? String) ?? fallback.checkedOffById {
            entry["checkedOffById"] = checkedOffById
        }
        // Creator attribution: shared reminders record their author in
        // sharedFrom/sharedFromId; personal reminders were created by the store
        // owner, i.e. the current user performing the deletion.
        if let createdBy = (data["sharedFrom"] as? String) ?? fallback.sharedFrom
            ?? UserSessionManager.shared.currentUser?.name {
            entry["createdBy"] = createdBy
        }
        if let createdById = (data["sharedFromId"] as? String) ?? fallback.sharedFromId
            ?? UserSessionManager.shared.currentUser?.userId {
            entry["createdById"] = createdById
        }

        Firestore.firestore().collection("reminder_history").addDocument(data: entry) { error in
            #if DEBUG
            if let error = error {
                print("ReminderViewModel: Error recording history entry: \(error.localizedDescription)")
            } else {
                print("ReminderViewModel: History entry recorded for '\(entry["title"] ?? "")'")
            }
            #endif
        }
    }

    /// Delete a reminder - syncs deletion across all linked shared reminders.
    /// Checked-off reminders are preserved in reminder_history before deletion.
    func deleteReminder(_ reminder: Reminder) {
        #if DEBUG
        print("ReminderViewModel: Deleting reminder '\(reminder.title)'")
        #endif

        pendingOtherChanges += 1

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
                        self.deleteSingleReminder(reminder.id, historySource: reminder)
                        return
                    }

                    guard let documents = snapshot?.documents, !documents.isEmpty else {
                        // No linked reminders found, delete just this one
                        self.deleteSingleReminder(reminder.id, historySource: reminder)
                        return
                    }

                    // Preserve checked-off copies in reminder_history (one entry
                    // per linked doc, so every participant's store keeps its own
                    // history). The local copy's isDone is authoritative when the
                    // check-off never reached Firestore (auto-delete flow).
                    // Photos referenced by history entries stay in Storage;
                    // everything else is cleaned up as before.
                    var photoURLs = Set<String>()
                    for doc in documents {
                        let data = doc.data()
                        let wasCheckedOff = (data["isDone"] as? Bool == true) || reminder.isDone
                        if wasCheckedOff {
                            Self.recordHistoryEntry(data: data, fallback: reminder)
                        } else if let urls = data["photoURLs"] as? [String] {
                            photoURLs.formUnion(urls)
                        }
                    }
                    Self.deletePhotosFromStorage(urls: photoURLs)

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
            deleteSingleReminder(reminder.id, historySource: reminder)
        }
    }

    /// Delete a single reminder document. When `historySource` is provided and
    /// the reminder was checked off, a reminder_history entry is written first
    /// (and its photos are kept in Storage since history still references them).
    /// `discardAutosave` passes no historySource — discarded drafts never get history.
    private func deleteSingleReminder(_ reminderId: String, historySource: Reminder? = nil) {
        let docRef = db.collection("reminders").document(reminderId)
        // Fetch photoURLs first so we can clean them up from Storage; without
        // this step the files are left orphaned after the doc is deleted.
        docRef.getDocument { snapshot, _ in
            let data = snapshot?.data() ?? [:]
            let wasCheckedOff = historySource.map {
                (data["isDone"] as? Bool == true) || $0.isDone
            } ?? false
            if wasCheckedOff, let source = historySource {
                Self.recordHistoryEntry(data: data, fallback: source)
            } else if let urls = data["photoURLs"] as? [String] {
                Self.deletePhotosFromStorage(urls: Set(urls))
            }
            docRef.delete { [weak self] error in
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
    }

    /// Fire-and-forget deletion of photo objects from Firebase Storage.
    /// Errors are logged but don't block Firestore deletions.
    static func deletePhotosFromStorage(urls: Set<String>) {
        for url in urls {
            let ref = Storage.storage().reference(forURL: url)
            ref.delete { error in
                #if DEBUG
                if let error = error {
                    print("ReminderViewModel: Failed to delete photo from storage: \(error.localizedDescription)")
                }
                #endif
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

        db.collection("reminders").document(reminder.id).updateData(
            ReminderEditAttribution.stamped(["photoURLs": currentURLs])
        ) { [weak self] error in
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

                // Recipient perspective takes precedence: sharedFromName is set
                // for anyone who received this store, including the merge flow
                // where their own sharedWith already contains the owner's name.
                if let sharedFromName = sharedFromName {
                    reminderData["sharedWith"] = [sharedFromName]
                } else if let sharedWith = sharedWith, !sharedWith.isEmpty {
                    reminderData["sharedWith"] = sharedWith
                }

                // Always persist creator attribution so the recipient's view
                // never has to guess who shared the reminder.
                if let currentUserName = currentUserName {
                    reminderData["sharedFrom"] = currentUserName
                }
                if let currentUserId = UserSessionManager.shared.currentUser?.userId {
                    reminderData["sharedFromId"] = currentUserId
                }
            }

            let docRef = db.collection("reminders").document()
            autosavedReminderId = docRef.documentID
            pendingAdditions += 1

            docRef.setData(reminderData) { [weak self] error in
                if let error = error {
                    #if DEBUG
                    print("ReminderViewModel: Error creating autosaved reminder: \(error.localizedDescription)")
                    #endif
                    DispatchQueue.main.async {
                        self?.autosavedReminderId = nil
                        self?.pendingAdditions = max(0, (self?.pendingAdditions ?? 1) - 1)
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
    func finalizeAutosave(userStoreId: String, finalTitle: String, useSmartCategory: Bool = true) {
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

        // Fire-and-forget AI categorization — works even after the ViewModel is deallocated
        // because it only captures the Firestore singleton and local values.
        // Only runs when Smart Category is enabled.
        if useSmartCategory {
            categorizeReminderDirectly(reminderId: reminderId, title: trimmedTitle)
        }
    }

    /// Categorize a reminder by ID and title directly via Firestore, without depending on the ViewModel lifecycle.
    /// Used by autosave finalization so categorization still runs even if the user navigates away.
    private func categorizeReminderDirectly(reminderId: String, title: String) {
        let db = self.db
        // Claim the reminder so a backlog pass doesn't categorize it a second time.
        aiCategorizationAttemptedIds.insert(reminderId)
        Task {
            do {
                let mapping = try await OpenAIService.shared.categorizeItems([title])
                let category = mapping[title] ?? "Uncategorized"
                if category != "Uncategorized" {
                    db.collection("reminders").document(reminderId).updateData([
                        "category": category
                    ]) { error in
                        #if DEBUG
                        if let error = error {
                            print("ReminderViewModel: Error categorizing autosaved reminder: \(error.localizedDescription)")
                        } else {
                            print("ReminderViewModel: Autosaved reminder categorized as '\(category)'")
                        }
                        #endif
                    }
                }
            } catch {
                #if DEBUG
                print("ReminderViewModel: AI categorization failed for '\(title)': \(error.localizedDescription)")
                #endif
            }
        }
    }

    /// Discard (delete) the autosaved reminder from Firestore
    func discardAutosave() {
        guard let reminderId = autosavedReminderId else { return }
        autosavedReminderId = nil
        // Undo the addition count since the reminder was created then immediately discarded
        pendingAdditions = max(0, pendingAdditions - 1)
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

                // Attaching a photo changes the item, so the row's avatar
                // follows whoever added it.
                self?.db.collection("reminders").document(reminder.id).updateData(
                    ReminderEditAttribution.stamped(["photoURLs": currentURLs])
                ) { error in
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
