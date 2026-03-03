// swift
// File: `Geolocation_v1.0.0/ViewModels/StoresViewModel.swift`

import Foundation
import FirebaseFirestore
import FirebaseAuth

class StoresViewModel: ObservableObject {
    private let db = Firestore.firestore()
    let sessionManager = UserSessionManager.shared // Changed from private to internal
    @Published var userStoreItems: [UserStoreItem] = [] // User's stores with user_store IDs
    @Published var allStores: [Store] = [] // All available stores for adding
    @Published var isLoading: Bool = false
    @Published var isLoadingAllStores: Bool = false
    @Published var errorMessage: String = ""

    // Store the listener registration so we can remove it later
    private var storesListener: ListenerRegistration?

    // Reminder count listeners for real-time updates (keyed by reminderStoreId)
    private var reminderCountListeners: [String: ListenerRegistration] = [:]

    // Shared status listeners to detect when recipients leave (keyed by owner's userStoreId)
    private var sharedStatusListeners: [String: ListenerRegistration] = [:]

    // Flag to prevent listener from overwriting during manual sort
    private var isManuallyReordering = false

    /// Fetch only stores that the current user has added to their list
    func fetchUserStores() {
        guard let userId = sessionManager.currentUser?.userId else {
            #if DEBUG
            print("StoresViewModel: No user data available in session, waiting...")
            #endif
            // Don't show error immediately - user data might still be loading
            isLoading = false
            return
        }

        isLoading = true
        #if DEBUG
        print("StoresViewModel: Fetching stores for userId: \(userId)")
        #endif
        self.fetchUserStoresById(userId: userId)
    }

    private func fetchUserStoresById(userId: String) {
        // Remove existing listeners to prevent duplicates
        storesListener?.remove()
        removeAllReminderCountListeners()
        removeAllSharedStatusListeners()

        // Add new snapshot listener and store the registration
        storesListener = db.collection("user_stores")
            .whereField("userId", isEqualTo: userId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }

                self.isLoading = false

                if let error = error {
                    #if DEBUG
                    print("StoresViewModel: Error fetching user stores: \(error.localizedDescription)")
                    #endif
                    self.errorMessage = "Error fetching stores: \(error.localizedDescription)"
                    return
                }

                guard let documents = snapshot?.documents else {
                    #if DEBUG
                    print("StoresViewModel: No stores found for user")
                    #endif
                    self.userStoreItems = []
                    self.removeAllReminderCountListeners()
                    self.removeAllSharedStatusListeners()
                    return
                }

                #if DEBUG
                print("StoresViewModel: Found \(documents.count) user stores")
                #endif

                // Preserve existing reminder counts so they aren't reset to 0
                // when the snapshot fires (e.g. after adding a new store)
                var existingReminderCounts: [String: Int] = [:]
                for item in self.userStoreItems {
                    let key = item.sourceUserStoreId ?? item.sharedStoreGroupId ?? item.id
                    existingReminderCounts[key] = item.store.reminderCount
                }

                // Parse user store data (without reminder counts initially)
                var tempUserStoreItems: [UserStoreItem] = []
                var reminderStoreIds: Set<String> = []

                for doc in documents {
                    let data = doc.data()
                    guard let storeId = data["storeId"] as? String,
                          let storeName = data["storeName"] as? String else {
                        #if DEBUG
                        print("StoresViewModel: Missing fields in user_store document")
                        #endif
                        continue
                    }

                    let userStoreId = doc.documentID
                    let sortOrder = data["sortOrder"] as? Int
                    let imageURL = data["imageURL"] as? String
                    let permissionString = data["permission"] as? String ?? "owner"
                    let permission = StorePermission(rawValue: permissionString) ?? .owner
                    let sharedStoreGroupId = data["sharedStoreGroupId"] as? String
                    let sourceUserStoreId = data["sourceUserStoreId"] as? String
                    let sharedFromName = data["sharedFromName"] as? String
                    let sharedFromId = data["sharedFrom"] as? String // userId of sharer
                    let sharedWith = data["sharedWith"] as? [String]
                    let notificationsEnabled = data["notificationsEnabled"] as? Bool ?? true

                    // Determine which ID to use for fetching reminders
                    let reminderStoreId = sourceUserStoreId ?? sharedStoreGroupId ?? userStoreId
                    reminderStoreIds.insert(reminderStoreId)

                    let store = Store(
                        id: storeId,
                        name: storeName,
                        reminderCount: existingReminderCounts[reminderStoreId] ?? 0,
                        sortOrder: sortOrder,
                        imageURL: imageURL
                    )
                    let userStoreItem = UserStoreItem(
                        id: userStoreId,
                        store: store,
                        permission: permission,
                        sharedStoreGroupId: sharedStoreGroupId,
                        sourceUserStoreId: sourceUserStoreId,
                        sharedFromName: sharedFromName,
                        sharedFromId: sharedFromId,
                        sharedWith: sharedWith,
                        notificationsEnabled: notificationsEnabled
                    )
                    tempUserStoreItems.append(userStoreItem)
                }

                // Skip updating if we're manually reordering
                guard !self.isManuallyReordering else {
                    #if DEBUG
                    print("StoresViewModel: Skipping listener update during manual reorder")
                    #endif
                    return
                }

                // Sort by sortOrder
                self.userStoreItems = tempUserStoreItems.sorted { item1, item2 in
                    let order1 = item1.store.sortOrder ?? Int.max
                    let order2 = item2.store.sortOrder ?? Int.max
                    return order1 < order2
                }

                // Push updated store list to the home screen widget
                WidgetDataStore.shared.updateWidgetData(from: self.userStoreItems)

                // Refresh stale sharedFromName values by looking up current names
                self.refreshSharedFromNames(for: self.userStoreItems)

                // Set up real-time listeners for reminder counts
                self.setupReminderCountListeners(for: reminderStoreIds)

                // Set up real-time listeners for shared store recipients
                self.setupSharedStatusListeners(for: tempUserStoreItems)

                #if DEBUG
                print("StoresViewModel: Loaded \(self.userStoreItems.count) stores, setting up reminder listeners")
                #endif
            }
    }

    /// Set up snapshot listeners for reminder counts (for real-time updates)
    private func setupReminderCountListeners(for reminderStoreIds: Set<String>) {
        // Remove listeners that are no longer needed
        let currentIds = Set(reminderCountListeners.keys)
        let idsToRemove = currentIds.subtracting(reminderStoreIds)
        for id in idsToRemove {
            reminderCountListeners[id]?.remove()
            reminderCountListeners.removeValue(forKey: id)
        }

        // Add listeners for new store IDs
        for reminderStoreId in reminderStoreIds {
            // Skip if already listening
            if reminderCountListeners[reminderStoreId] != nil {
                continue
            }

            let listener = db.collection("reminders")
                .whereField("userStoreId", isEqualTo: reminderStoreId)
                .whereField("isDone", isEqualTo: false)
                .addSnapshotListener { [weak self] snapshot, error in
                    guard let self = self else { return }

                    if let error = error {
                        #if DEBUG
                        print("StoresViewModel: Error listening to reminders for \(reminderStoreId): \(error)")
                        #endif
                        return
                    }

                    let reminderCount = snapshot?.documents.count ?? 0
                    self.updateReminderCount(for: reminderStoreId, count: reminderCount)
                }

            reminderCountListeners[reminderStoreId] = listener
        }
    }

    /// Update the reminder count for stores matching the given reminderStoreId
    private func updateReminderCount(for reminderStoreId: String, count: Int) {
        // Skip if manually reordering
        guard !isManuallyReordering else { return }

        // Find and update all UserStoreItems that use this reminderStoreId
        var updated = false
        for (index, item) in userStoreItems.enumerated() {
            let itemReminderStoreId = item.sourceUserStoreId ?? item.sharedStoreGroupId ?? item.id

            if itemReminderStoreId == reminderStoreId && item.store.reminderCount != count {
                // Create updated store with new count
                let updatedStore = Store(
                    id: item.store.id,
                    name: item.store.name,
                    reminderCount: count,
                    sortOrder: item.store.sortOrder,
                    imageURL: item.store.imageURL
                )
                let updatedItem = UserStoreItem(
                    id: item.id,
                    store: updatedStore,
                    permission: item.permission,
                    sharedStoreGroupId: item.sharedStoreGroupId,
                    sourceUserStoreId: item.sourceUserStoreId,
                    sharedFromName: item.sharedFromName,
                    sharedFromId: item.sharedFromId,
                    sharedWith: item.sharedWith,
                    notificationsEnabled: item.notificationsEnabled
                )
                userStoreItems[index] = updatedItem
                updated = true
                #if DEBUG
                print("StoresViewModel: Updated reminder count for '\(item.store.name)' to \(count)")
                #endif
            }
        }

        if updated {
            // Trigger UI update by reassigning (in case SwiftUI doesn't detect the change)
            objectWillChange.send()
            // Push updated reminder counts to the home screen widget
            WidgetDataStore.shared.updateWidgetData(from: userStoreItems)
        }
    }

    /// Remove all reminder count listeners
    private func removeAllReminderCountListeners() {
        for (_, listener) in reminderCountListeners {
            listener.remove()
        }
        reminderCountListeners.removeAll()
    }

    /// Set up real-time listeners to detect when shared store recipients join or leave.
    /// Watches all owner stores for recipient user_store documents (via sourceUserStoreId).
    /// Directly updates the local userStoreItems array for instant UI feedback,
    /// and also persists changes to Firestore for durability.
    private func setupSharedStatusListeners(for items: [UserStoreItem]) {
        // Monitor all owner stores — recipients can appear at any time after a share invite
        let ownerItemIds = Set(items.compactMap { item -> String? in
            item.permission == .owner ? item.id : nil
        })

        // Remove listeners for stores no longer in the list
        let currentIds = Set(sharedStatusListeners.keys)
        let idsToRemove = currentIds.subtracting(ownerItemIds)
        for id in idsToRemove {
            sharedStatusListeners[id]?.remove()
            sharedStatusListeners.removeValue(forKey: id)
        }

        // Add listeners for owner stores
        for item in items {
            guard item.permission == .owner else { continue }

            // Skip if already listening
            if sharedStatusListeners[item.id] != nil { continue }

            let ownerStoreId = item.id
            let storeName = item.store.name
            let listener = db.collection("user_stores")
                .whereField("sourceUserStoreId", isEqualTo: ownerStoreId)
                .addSnapshotListener { [weak self] snapshot, error in
                    guard let self = self, let snapshot = snapshot else {
                        #if DEBUG
                        if let error = error {
                            print("StoresViewModel: Error in shared status listener for \(storeName): \(error.localizedDescription)")
                        }
                        #endif
                        return
                    }

                    let hasAdditions = snapshot.documentChanges.contains { $0.type == .added }
                    let hasRemovals = snapshot.documentChanges.contains { $0.type == .removed }

                    // Only react to actual recipient additions or removals
                    guard hasAdditions || hasRemovals else { return }

                    if snapshot.documents.isEmpty {
                        #if DEBUG
                        print("StoresViewModel: Last recipient left '\(storeName)' - clearing sharedWith")
                        #endif

                        // Update local array immediately for instant UI feedback
                        if let index = self.userStoreItems.firstIndex(where: { $0.id == ownerStoreId }) {
                            self.userStoreItems[index].sharedWith = nil
                        }

                        // Persist to Firestore
                        self.db.collection("user_stores").document(ownerStoreId).updateData([
                            "sharedWith": FieldValue.delete(),
                            "isSharedStore": FieldValue.delete()
                        ])
                    } else {
                        // Build sharedWith from current recipient documents
                        let recipientNames = snapshot.documents.compactMap { doc in
                            doc.data()["userName"] as? String
                        }

                        if !recipientNames.isEmpty {
                            #if DEBUG
                            print("StoresViewModel: Recipients changed for '\(storeName)' - sharedWith=\(recipientNames)")
                            #endif

                            // Update local array immediately for instant UI feedback
                            if let index = self.userStoreItems.firstIndex(where: { $0.id == ownerStoreId }) {
                                self.userStoreItems[index].sharedWith = recipientNames
                            }

                            // Persist to Firestore
                            self.db.collection("user_stores").document(ownerStoreId).updateData([
                                "sharedWith": recipientNames,
                                "isSharedStore": true
                            ])
                        }
                    }
                }

            sharedStatusListeners[item.id] = listener
        }
    }

    /// Look up the current display name for each sharer and update stale sharedFromName values.
    /// This "self-heals" the cached name so the other user always sees the sharer's latest name.
    private func refreshSharedFromNames(for items: [UserStoreItem]) {
        // Collect shared stores that have a sharedFromId (userId of the person who shared)
        var sharerIdToStoreIndices: [String: [Int]] = [:]
        for (index, item) in items.enumerated() {
            guard let sharedFromId = item.sharedFromId, !sharedFromId.isEmpty else { continue }
            sharerIdToStoreIndices[sharedFromId, default: []].append(index)
        }

        guard !sharerIdToStoreIndices.isEmpty else { return }

        let sharerIds = Array(sharerIdToStoreIndices.keys)

        // Firestore `whereField("in")` supports up to 10 values per query
        let chunks = stride(from: 0, to: sharerIds.count, by: 10).map {
            Array(sharerIds[$0..<min($0 + 10, sharerIds.count)])
        }

        for chunk in chunks {
            db.collection("users")
                .whereField("userId", in: chunk)
                .getDocuments { [weak self] snapshot, error in
                    guard let self = self else { return }

                    if let error = error {
                        #if DEBUG
                        print("StoresViewModel: Error looking up sharer names: \(error.localizedDescription)")
                        #endif
                        return
                    }

                    guard let documents = snapshot?.documents else { return }

                    // Build a map of userId -> current display name
                    var currentNames: [String: String] = [:]
                    for doc in documents {
                        let data = doc.data()
                        if let userId = data["userId"] as? String,
                           let name = data["name"] as? String {
                            currentNames[userId] = name
                        }
                    }

                    // Check each shared store and update if the name is stale
                    for (sharerId, indices) in sharerIdToStoreIndices {
                        guard let currentName = currentNames[sharerId] else { continue }

                        for index in indices {
                            guard index < self.userStoreItems.count else { continue }
                            let item = self.userStoreItems[index]
                            // Only update if sharedFromId matches (guard against array shifts)
                            guard item.sharedFromId == sharerId else { continue }

                            if item.sharedFromName != currentName {
                                #if DEBUG
                                print("StoresViewModel: Updating stale sharedFromName for '\(item.store.name)': '\(item.sharedFromName ?? "nil")' -> '\(currentName)'")
                                #endif

                                // Update in-memory
                                self.userStoreItems[index].sharedFromName = currentName

                                // Persist to this user's own user_store document (allowed by security rules)
                                self.db.collection("user_stores").document(item.id).updateData([
                                    "sharedFromName": currentName
                                ])
                            }
                        }
                    }
                }
        }
    }

    /// Remove all shared status listeners
    private func removeAllSharedStatusListeners() {
        for (_, listener) in sharedStatusListeners {
            listener.remove()
        }
        sharedStatusListeners.removeAll()
    }

    /// Fetch all available stores from the stores collection
    func fetchAllStores() {
        // Check if user is authenticated
        guard Auth.auth().currentUser != nil else {
            #if DEBUG
            print("StoresViewModel: User not authenticated, cannot fetch stores")
            #endif
            DispatchQueue.main.async {
                self.isLoadingAllStores = false
                self.errorMessage = "Please log in to view available stores."
            }
            return
        }

        #if DEBUG
        print("StoresViewModel: Fetching all available stores")
        #endif

        DispatchQueue.main.async {
            self.isLoadingAllStores = true
            self.errorMessage = "" // Clear any previous errors
        }

        db.collection("stores").getDocuments { [weak self] snapshot, error in
            guard let self = self else { return }

            if let error = error {
                let nsError = error as NSError
                #if DEBUG
                print("StoresViewModel: Error fetching all stores: \(error.localizedDescription)")
                print("StoresViewModel: Error code: \(nsError.code), domain: \(nsError.domain)")
                #endif

                DispatchQueue.main.async {
                    self.isLoadingAllStores = false

                    // Provide more specific error messages
                    if nsError.domain == "FIRFirestoreErrorDomain" && nsError.code == 7 {
                        // Permission denied error
                        self.errorMessage = "Unable to access stores database. Please ensure:\n1. You are logged in\n2. Firestore security rules are deployed\n3. You have an active internet connection"
                    } else {
                        self.errorMessage = "Error loading stores: \(error.localizedDescription)"
                    }
                }
                return
            }

            guard let documents = snapshot?.documents else {
                #if DEBUG
                print("StoresViewModel: No stores in database")
                #endif
                DispatchQueue.main.async {
                    self.isLoadingAllStores = false
                }
                return
            }

            let stores = documents.compactMap { doc -> Store? in
                let data = doc.data()
                guard let name = data["name"] as? String else {
                    return nil
                }
                let imageURL = data["imageURL"] as? String
                return Store(
                    id: doc.documentID,
                    name: name,
                    reminderCount: 0,
                    sortOrder: nil,
                    imageURL: imageURL
                )
            }

            DispatchQueue.main.async {
                self.allStores = stores
                self.isLoadingAllStores = false
                self.errorMessage = "" // Clear error on success
                #if DEBUG
                print("StoresViewModel: Loaded \(self.allStores.count) available stores")
                #endif
            }
        }
    }

    /// Add a store to the current user's list
    /// Stores are identified by name - adding "Walmart" tracks all Walmart locations
    func addStoreToUser(store: Store) {
        guard let userId = sessionManager.currentUser?.userId,
              let userEmail = sessionManager.currentUser?.email else {
            DispatchQueue.main.async {
                self.errorMessage = "No user data available"
            }
            return
        }

        #if DEBUG
        print("StoresViewModel: Adding store '\(store.name)' to user")
        #endif

        // Check if store is already added (by normalized store ID based on name)
        let normalizedStoreId = Store.normalizedId(from: store.name)
        db.collection("user_stores")
            .whereField("userId", isEqualTo: userId)
            .whereField("storeId", isEqualTo: normalizedStoreId)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }

                if let documents = snapshot?.documents, !documents.isEmpty {
                    DispatchQueue.main.async {
                        self.errorMessage = "Store already added"
                    }
                    return
                }

                // Add store to user's list
                let sortOrder = self.userStoreItems.count
                var userStore: [String: Any] = [
                    "userId": userId,
                    "userEmail": userEmail,
                    "storeId": normalizedStoreId,
                    "storeName": store.name,
                    "addedAt": Date().timeIntervalSince1970,
                    "sortOrder": sortOrder
                ]

                // Add image URL if available
                if let imageURL = store.imageURL {
                    userStore["imageURL"] = imageURL
                }

                self.db.collection("user_stores").addDocument(data: userStore) { error in
                    if let error = error {
                        #if DEBUG
                        print("StoresViewModel: Error adding store: \(error.localizedDescription)")
                        #endif
                        DispatchQueue.main.async {
                            self.errorMessage = "Error adding store: \(error.localizedDescription)"
                        }
                    } else {
                        #if DEBUG
                        print("StoresViewModel: Store '\(store.name)' added successfully")
                        #endif
                    }
                }
            }
    }

    /// Remove a store from the current user's list
    func removeStoreFromUser(userStoreItem: UserStoreItem) {
        #if DEBUG
        print("StoresViewModel: Removing user_store document: \(userStoreItem.id)")
        #endif

        // Remove from local array immediately for smooth UI
        userStoreItems.removeAll { $0.id == userStoreItem.id }
        // Reflect removal in the home screen widget immediately
        WidgetDataStore.shared.updateWidgetData(from: userStoreItems)

        // Use the permission information already available in userStoreItem
        // instead of fetching the document again (which could fail and leave orphaned reminders)
        let permission = userStoreItem.permission
        let sharedGroupId = userStoreItem.sharedStoreGroupId
        let isRecipient = userStoreItem.sharedFromName != nil // If sharedFromName is set, user is a recipient

        // Check if this is a shared store with Can Edit permission and a shared group
        if permission == .edit, let sharedGroupId = sharedGroupId {
            // Delete all user_stores and reminders in the shared group
            self.deleteSharedStoreGroup(sharedGroupId: sharedGroupId)
        } else if isRecipient {
            // Recipient (view or edit without shared group) - delete user_store and update owner's reminders
            self.deleteRecipientUserStore(userStoreItem: userStoreItem)
        } else {
            // Owner without sharing - delete user_store and its reminders
            self.deleteSingleUserStore(userStoreItem: userStoreItem)
        }
    }

    private func deleteSingleUserStore(userStoreItem: UserStoreItem) {
        #if DEBUG
        print("StoresViewModel: Deleting single user_store: \(userStoreItem.id)")
        #endif

        // Delete the user_store document
        db.collection("user_stores").document(userStoreItem.id).delete { [weak self] error in
            if let error = error {
                #if DEBUG
                print("StoresViewModel: Error removing store: \(error.localizedDescription)")
                #endif
                DispatchQueue.main.async {
                    self?.errorMessage = "Failed to delete store: \(error.localizedDescription)"
                }
            } else {
                #if DEBUG
                print("StoresViewModel: Store removed successfully")
                #endif
            }
        }

        // Delete all reminders for this user_store
        db.collection("reminders")
            .whereField("userStoreId", isEqualTo: userStoreItem.id)
            .getDocuments { [weak self] snapshot, error in
                if let error = error {
                    #if DEBUG
                    print("StoresViewModel: Error fetching reminders: \(error.localizedDescription)")
                    #endif
                    DispatchQueue.main.async {
                        self?.errorMessage = "Failed to clean up reminders: \(error.localizedDescription)"
                    }
                    return
                }

                guard let documents = snapshot?.documents, !documents.isEmpty else {
                    return
                }

                let batch = self?.db.batch()
                for doc in documents {
                    batch?.deleteDocument(doc.reference)
                }

                batch?.commit { error in
                    if let error = error {
                        #if DEBUG
                        print("StoresViewModel: Error deleting reminders: \(error.localizedDescription)")
                        #endif
                        DispatchQueue.main.async {
                            self?.errorMessage = "Failed to delete reminders: \(error.localizedDescription)"
                        }
                    } else {
                        #if DEBUG
                        print("StoresViewModel: Deleted \(documents.count) reminders")
                        #endif
                    }
                }
            }
    }

    private func deleteRecipientUserStore(userStoreItem: UserStoreItem) {
        #if DEBUG
        print("StoresViewModel: Deleting recipient's shared user_store: \(userStoreItem.id)")
        #endif

        // Get current user's name to remove from owner's reminders and user_store sharedWith
        let currentUserName = sessionManager.currentUser?.name

        // Only delete the user_store document, don't touch owner's reminders
        db.collection("user_stores").document(userStoreItem.id).delete { [weak self] error in
            if let error = error {
                #if DEBUG
                print("StoresViewModel: Error removing shared store: \(error.localizedDescription)")
                #endif
                DispatchQueue.main.async {
                    self?.errorMessage = "Failed to delete shared store: \(error.localizedDescription)"
                }
            } else {
                #if DEBUG
                print("StoresViewModel: Shared store removed successfully (recipient left)")
                #endif

                if let currentUserName = currentUserName,
                   let sourceUserStoreId = userStoreItem.sourceUserStoreId {
                    // Update owner's reminders to remove current user from sharedWith
                    self?.updateOwnerRemindersAfterRecipientLeaves(
                        ownerUserStoreId: sourceUserStoreId,
                        recipientName: currentUserName
                    )

                    // Update owner's user_store to remove current user from sharedWith
                    self?.updateOwnerUserStoreAfterRecipientLeaves(
                        ownerUserStoreId: sourceUserStoreId,
                        recipientName: currentUserName
                    )
                }
            }
        }
    }

    private func updateOwnerRemindersAfterRecipientLeaves(ownerUserStoreId: String, recipientName: String) {
        #if DEBUG
        print("StoresViewModel: Updating reminders after \(recipientName) left the shared store")
        #endif

        // Find all shared reminders for the owner's store
        db.collection("reminders")
            .whereField("userStoreId", isEqualTo: ownerUserStoreId)
            .whereField("isShared", isEqualTo: true)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }

                if let error = error {
                    #if DEBUG
                    print("StoresViewModel: Error fetching reminders to update: \(error.localizedDescription)")
                    #endif
                    DispatchQueue.main.async {
                        self.errorMessage = "Failed to update shared reminders: \(error.localizedDescription)"
                    }
                    return
                }

                guard let documents = snapshot?.documents, !documents.isEmpty else {
                    #if DEBUG
                    print("StoresViewModel: No shared reminders to update")
                    #endif
                    return
                }

                let batch = self.db.batch()
                var updatedCount = 0

                for doc in documents {
                    let data = doc.data()
                    var sharedWith = data["sharedWith"] as? [String] ?? []
                    let sharedFrom = data["sharedFrom"] as? String

                    var needsUpdate = false
                    var clearSharedStatus = false

                    // Case 1: Reminder created by owner, shared with recipient
                    // Remove the recipient from sharedWith
                    if sharedWith.contains(recipientName) {
                        sharedWith.removeAll { $0 == recipientName }
                        needsUpdate = true

                        if sharedWith.isEmpty {
                            clearSharedStatus = true
                        }
                    }

                    // Case 2: Reminder created by recipient (sharedFrom = recipient's name)
                    // Clear the shared status entirely since the creator left
                    if sharedFrom == recipientName {
                        clearSharedStatus = true
                        needsUpdate = true
                    }

                    if needsUpdate {
                        updatedCount += 1

                        if clearSharedStatus {
                            // No more sharing, remove shared status completely
                            batch.updateData([
                                "isShared": false,
                                "sharedWith": FieldValue.delete(),
                                "sharedFrom": FieldValue.delete()
                            ], forDocument: doc.reference)
                        } else {
                            // Update with remaining shared users
                            batch.updateData([
                                "sharedWith": sharedWith
                            ], forDocument: doc.reference)
                        }
                    }
                }

                if updatedCount > 0 {
                    batch.commit { [weak self] error in
                        if let error = error {
                            #if DEBUG
                            print("StoresViewModel: Error updating reminders: \(error.localizedDescription)")
                            #endif
                            DispatchQueue.main.async {
                                self?.errorMessage = "Failed to update shared reminders: \(error.localizedDescription)"
                            }
                        } else {
                            #if DEBUG
                            print("StoresViewModel: Updated \(updatedCount) reminders after recipient left")
                            #endif
                        }
                    }
                }
            }
    }

    private func updateOwnerUserStoreAfterRecipientLeaves(ownerUserStoreId: String, recipientName: String) {
        #if DEBUG
        print("StoresViewModel: Updating owner's user_store \(ownerUserStoreId) to remove \(recipientName) from sharedWith")
        #endif

        let ownerDocRef = db.collection("user_stores").document(ownerUserStoreId)
        ownerDocRef.getDocument { [weak self] snapshot, error in
            if let error = error {
                #if DEBUG
                print("StoresViewModel: Error fetching owner's user_store: \(error.localizedDescription)")
                #endif
                return
            }

            guard let data = snapshot?.data() else {
                #if DEBUG
                print("StoresViewModel: Owner's user_store not found")
                #endif
                return
            }

            var sharedWith = data["sharedWith"] as? [String] ?? []
            sharedWith.removeAll { $0 == recipientName }

            if sharedWith.isEmpty {
                // No more shared users, clear sharing fields
                ownerDocRef.updateData([
                    "sharedWith": FieldValue.delete(),
                    "isSharedStore": FieldValue.delete()
                ]) { error in
                    #if DEBUG
                    if let error = error {
                        print("StoresViewModel: Error clearing owner's sharedWith: \(error.localizedDescription)")
                    } else {
                        print("StoresViewModel: Cleared owner's sharedWith (no more recipients)")
                    }
                    #endif
                }
            } else {
                // Update with remaining shared users
                ownerDocRef.updateData([
                    "sharedWith": sharedWith
                ]) { error in
                    #if DEBUG
                    if let error = error {
                        print("StoresViewModel: Error updating owner's sharedWith: \(error.localizedDescription)")
                    } else {
                        print("StoresViewModel: Updated owner's sharedWith to \(sharedWith)")
                    }
                    #endif
                }
            }
        }
    }

    private func deleteSharedStoreGroup(sharedGroupId: String) {
        #if DEBUG
        print("StoresViewModel: Deleting shared store group: \(sharedGroupId)")
        #endif

        // Step 1: Delete the shared store group first
        // This allows the Firestore rules to permit deletion of user_stores
        let sharedGroupRef = db.collection("shared_store_groups").document(sharedGroupId)
        sharedGroupRef.delete { [weak self] error in
            guard let self = self else { return }

            if let error = error {
                #if DEBUG
                print("StoresViewModel: Error deleting shared group: \(error.localizedDescription)")
                #endif
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to delete shared store group: \(error.localizedDescription)"
                }
                return
            }

            #if DEBUG
            print("StoresViewModel: Shared group deleted, now deleting user_stores and reminders")
            #endif

            // Step 2: Find all user_stores in this shared group
            self.db.collection("user_stores")
                .whereField("sharedStoreGroupId", isEqualTo: sharedGroupId)
                .getDocuments { [weak self] snapshot, error in
                    if let error = error {
                        #if DEBUG
                        print("StoresViewModel: Error fetching shared user_stores: \(error.localizedDescription)")
                        #endif
                        DispatchQueue.main.async {
                            self?.errorMessage = "Failed to delete shared stores: \(error.localizedDescription)"
                        }
                        return
                    }

                    guard let userStoreDocuments = snapshot?.documents else {
                        return
                    }

                    // Step 3: Delete all reminders associated with the shared group
                    self?.db.collection("reminders")
                        .whereField("userStoreId", isEqualTo: sharedGroupId)
                        .getDocuments { [weak self] reminderSnapshot, reminderError in
                            if let reminderError = reminderError {
                                #if DEBUG
                                print("StoresViewModel: Error fetching reminders: \(reminderError.localizedDescription)")
                                #endif
                                DispatchQueue.main.async {
                                    self?.errorMessage = "Failed to clean up shared reminders: \(reminderError.localizedDescription)"
                                }
                                return
                            }

                            // Step 4: Use batch to delete user_stores and reminders
                            // Now allowed because shared group no longer exists
                            guard let batch = self?.db.batch() else { return }

                            // Delete all user_stores
                            for doc in userStoreDocuments {
                                batch.deleteDocument(doc.reference)
                            }

                            // Delete all reminders
                            if let reminderDocs = reminderSnapshot?.documents {
                                for doc in reminderDocs {
                                    batch.deleteDocument(doc.reference)
                                }
                            }

                            // Commit the batch
                            batch.commit { error in
                                if let error = error {
                                    #if DEBUG
                                    print("StoresViewModel: Error deleting user_stores and reminders: \(error.localizedDescription)")
                                    #endif
                                    DispatchQueue.main.async {
                                        self?.errorMessage = "Failed to delete shared stores and reminders: \(error.localizedDescription)"
                                    }
                                } else {
                                    #if DEBUG
                                    print("StoresViewModel: Successfully deleted \(userStoreDocuments.count) user_stores and \(reminderSnapshot?.documents.count ?? 0) reminders")
                                    #endif
                                }
                            }
                        }
                }
        }
    }

    /// Reorder stores when user drags and drops
    func moveStore(from source: IndexSet, to destination: Int) {
        // Set flag to prevent listener from overwriting during reorder
        isManuallyReordering = true

        // Reorder the local array
        var updatedItems = userStoreItems
        updatedItems.move(fromOffsets: source, toOffset: destination)

        // Update the local state immediately for smooth UI
        userStoreItems = updatedItems
        // Reflect reordering in the home screen widget
        WidgetDataStore.shared.updateWidgetData(from: userStoreItems)

        // Update sortOrder for all items in Firestore
        let batch = db.batch()
        for (index, item) in updatedItems.enumerated() {
            let docRef = db.collection("user_stores").document(item.id)
            batch.updateData(["sortOrder": index], forDocument: docRef)
        }

        batch.commit { [weak self] error in
            // Re-enable listener updates after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self?.isManuallyReordering = false
            }

            if let error = error {
                #if DEBUG
                print("StoresViewModel: Error updating sort order: \(error.localizedDescription)")
                #endif
            } else {
                #if DEBUG
                print("StoresViewModel: Sort order updated successfully")
                #endif
            }
        }
    }

    // MARK: - On My Way Notification

    @Published var isSendingOnMyWay = false
    @Published var onMyWayError: String?
    @Published var onMyWaySentStoreName: String?

    /// Send "on my way" notification to all users sharing the given store.
    /// Calculates driving time from the user's current location to the nearest store location.
    func sendOnMyWayNotification(for userStoreItem: UserStoreItem) {
        guard let currentUser = sessionManager.currentUser else {
            onMyWayError = "User data not available."
            return
        }

        isSendingOnMyWay = true
        onMyWayError = nil
        onMyWaySentStoreName = nil

        TravelTimeService.shared.calculateTravelTime(to: userStoreItem.store.name) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }

                switch result {
                case .success(let estimate):
                    #if DEBUG
                    print("🚗 StoresViewModel: Travel time to \(userStoreItem.store.name): \(estimate.formattedTravelTime)")
                    #endif

                    OnMyWayNotificationService.shared.sendNotification(
                        for: userStoreItem,
                        travelTimeMinutes: estimate.travelTimeMinutes,
                        currentUserId: currentUser.userId,
                        currentUserName: currentUser.name
                    )

                    self.isSendingOnMyWay = false
                    self.onMyWaySentStoreName = userStoreItem.store.name

                case .failure(let error):
                    #if DEBUG
                    print("🚗 StoresViewModel: Failed to calculate travel time: \(error.localizedDescription)")
                    #endif
                    self.isSendingOnMyWay = false
                    self.onMyWayError = error.localizedDescription
                }
            }
        }
    }

    deinit {
        // Clean up listeners when ViewModel is destroyed
        storesListener?.remove()
        removeAllReminderCountListeners()
        removeAllSharedStatusListeners()
    }
}
