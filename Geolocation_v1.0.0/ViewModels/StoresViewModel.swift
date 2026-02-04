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

    // Flag to prevent listener from overwriting during manual sort
    private var isManuallyReordering = false

    /// Fetch only stores that the current user has added to their list
    func fetchUserStores() {
        guard let userId = sessionManager.currentUser?.userId else {
            print("StoresViewModel: No user data available in session, waiting...")
            // Don't show error immediately - user data might still be loading
            isLoading = false
            return
        }

        isLoading = true
        print("StoresViewModel: Fetching stores for userId: \(userId)")
        self.fetchUserStoresById(userId: userId)
    }

    private func fetchUserStoresById(userId: String) {
        // Remove existing listeners to prevent duplicates
        storesListener?.remove()
        removeAllReminderCountListeners()

        // Add new snapshot listener and store the registration
        storesListener = db.collection("user_stores")
            .whereField("userId", isEqualTo: userId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }

                self.isLoading = false

                if let error = error {
                    print("StoresViewModel: Error fetching user stores: \(error.localizedDescription)")
                    self.errorMessage = "Error fetching stores: \(error.localizedDescription)"
                    return
                }

                guard let documents = snapshot?.documents else {
                    print("StoresViewModel: No stores found for user")
                    self.userStoreItems = []
                    self.removeAllReminderCountListeners()
                    return
                }

                print("StoresViewModel: Found \(documents.count) user stores")

                // Parse user store data (without reminder counts initially)
                var tempUserStoreItems: [UserStoreItem] = []
                var reminderStoreIds: Set<String> = []

                for doc in documents {
                    let data = doc.data()
                    guard let storeId = data["storeId"] as? String,
                          let storeName = data["storeName"] as? String else {
                        print("StoresViewModel: Missing fields in user_store document")
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
                    let sharedWith = data["sharedWith"] as? [String]
                    let notificationsEnabled = data["notificationsEnabled"] as? Bool ?? true

                    // Determine which ID to use for fetching reminders
                    let reminderStoreId = sourceUserStoreId ?? sharedStoreGroupId ?? userStoreId
                    reminderStoreIds.insert(reminderStoreId)

                    let store = Store(
                        id: storeId,
                        name: storeName,
                        reminderCount: 0, // Will be updated by reminder listener
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
                        sharedWith: sharedWith,
                        notificationsEnabled: notificationsEnabled
                    )
                    tempUserStoreItems.append(userStoreItem)
                }

                // Skip updating if we're manually reordering
                guard !self.isManuallyReordering else {
                    print("StoresViewModel: Skipping listener update during manual reorder")
                    return
                }

                // Sort by sortOrder
                self.userStoreItems = tempUserStoreItems.sorted { item1, item2 in
                    let order1 = item1.store.sortOrder ?? Int.max
                    let order2 = item2.store.sortOrder ?? Int.max
                    return order1 < order2
                }

                // Set up real-time listeners for reminder counts
                self.setupReminderCountListeners(for: reminderStoreIds)

                print("StoresViewModel: Loaded \(self.userStoreItems.count) stores, setting up reminder listeners")
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
                        print("StoresViewModel: Error listening to reminders for \(reminderStoreId): \(error)")
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
                    sharedWith: item.sharedWith,
                    notificationsEnabled: item.notificationsEnabled
                )
                userStoreItems[index] = updatedItem
                updated = true
                print("StoresViewModel: Updated reminder count for '\(item.store.name)' to \(count)")
            }
        }

        if updated {
            // Trigger UI update by reassigning (in case SwiftUI doesn't detect the change)
            objectWillChange.send()
        }
    }

    /// Remove all reminder count listeners
    private func removeAllReminderCountListeners() {
        for (_, listener) in reminderCountListeners {
            listener.remove()
        }
        reminderCountListeners.removeAll()
    }

    /// Fetch all available stores from the stores collection
    func fetchAllStores() {
        // Check if user is authenticated
        guard Auth.auth().currentUser != nil else {
            print("StoresViewModel: User not authenticated, cannot fetch stores")
            DispatchQueue.main.async {
                self.isLoadingAllStores = false
                self.errorMessage = "Please log in to view available stores."
            }
            return
        }

        print("StoresViewModel: Fetching all available stores")

        DispatchQueue.main.async {
            self.isLoadingAllStores = true
            self.errorMessage = "" // Clear any previous errors
        }

        db.collection("stores").getDocuments { [weak self] snapshot, error in
            guard let self = self else { return }

            if let error = error {
                let nsError = error as NSError
                print("StoresViewModel: Error fetching all stores: \(error.localizedDescription)")
                print("StoresViewModel: Error code: \(nsError.code), domain: \(nsError.domain)")

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
                print("StoresViewModel: No stores in database")
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
                print("StoresViewModel: Loaded \(self.allStores.count) available stores")
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

        print("StoresViewModel: Adding store '\(store.name)' to user")

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
                        print("StoresViewModel: Error adding store: \(error.localizedDescription)")
                        DispatchQueue.main.async {
                            self.errorMessage = "Error adding store: \(error.localizedDescription)"
                        }
                    } else {
                        print("StoresViewModel: Store '\(store.name)' added successfully")
                    }
                }
            }
    }

    /// Remove a store from the current user's list
    func removeStoreFromUser(userStoreItem: UserStoreItem) {
        print("StoresViewModel: Removing user_store document: \(userStoreItem.id)")

        // Remove from local array immediately for smooth UI
        userStoreItems.removeAll { $0.id == userStoreItem.id }

        // Use the permission information already available in userStoreItem
        // instead of fetching the document again (which could fail and leave orphaned reminders)
        let permission = userStoreItem.permission
        let sharedGroupId = userStoreItem.sharedStoreGroupId

        // Check if this is a shared store with Can Edit permission
        if permission == .edit, let sharedGroupId = sharedGroupId {
            // Delete all user_stores and reminders in the shared group
            self.deleteSharedStoreGroup(sharedGroupId: sharedGroupId)
        } else if permission == .view {
            // View Only - just delete this user's user_store, don't touch owner's reminders
            self.deleteViewOnlyUserStore(userStoreItem: userStoreItem)
        } else {
            // Owner without sharing - delete user_store and its reminders
            self.deleteSingleUserStore(userStoreItem: userStoreItem)
        }
    }

    private func deleteSingleUserStore(userStoreItem: UserStoreItem) {
        print("StoresViewModel: Deleting single user_store: \(userStoreItem.id)")

        // Delete the user_store document
        db.collection("user_stores").document(userStoreItem.id).delete { error in
            if let error = error {
                print("StoresViewModel: Error removing store: \(error.localizedDescription)")
            } else {
                print("StoresViewModel: Store removed successfully")
            }
        }

        // Delete all reminders for this user_store
        db.collection("reminders")
            .whereField("userStoreId", isEqualTo: userStoreItem.id)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("StoresViewModel: Error fetching reminders: \(error.localizedDescription)")
                    return
                }

                guard let documents = snapshot?.documents, !documents.isEmpty else {
                    return
                }

                let batch = self.db.batch()
                for doc in documents {
                    batch.deleteDocument(doc.reference)
                }

                batch.commit { error in
                    if let error = error {
                        print("StoresViewModel: Error deleting reminders: \(error.localizedDescription)")
                    } else {
                        print("StoresViewModel: Deleted \(documents.count) reminders")
                    }
                }
            }
    }

    private func deleteViewOnlyUserStore(userStoreItem: UserStoreItem) {
        print("StoresViewModel: Deleting view-only user_store: \(userStoreItem.id)")

        // Only delete the user_store document, don't touch owner's reminders
        db.collection("user_stores").document(userStoreItem.id).delete { error in
            if let error = error {
                print("StoresViewModel: Error removing view-only store: \(error.localizedDescription)")
            } else {
                print("StoresViewModel: View-only store removed successfully (unshared from user)")
            }
        }
    }

    private func deleteSharedStoreGroup(sharedGroupId: String) {
        print("StoresViewModel: Deleting shared store group: \(sharedGroupId)")

        // Step 1: Delete the shared store group first
        // This allows the Firestore rules to permit deletion of user_stores
        let sharedGroupRef = db.collection("shared_store_groups").document(sharedGroupId)
        sharedGroupRef.delete { [weak self] error in
            guard let self = self else { return }

            if let error = error {
                print("StoresViewModel: Error deleting shared group: \(error.localizedDescription)")
                return
            }

            print("StoresViewModel: Shared group deleted, now deleting user_stores and reminders")

            // Step 2: Find all user_stores in this shared group
            self.db.collection("user_stores")
                .whereField("sharedStoreGroupId", isEqualTo: sharedGroupId)
                .getDocuments { snapshot, error in
                    if let error = error {
                        print("StoresViewModel: Error fetching shared user_stores: \(error.localizedDescription)")
                        return
                    }

                    guard let userStoreDocuments = snapshot?.documents else {
                        return
                    }

                    // Step 3: Delete all reminders associated with the shared group
                    self.db.collection("reminders")
                        .whereField("userStoreId", isEqualTo: sharedGroupId)
                        .getDocuments { reminderSnapshot, reminderError in
                            if let reminderError = reminderError {
                                print("StoresViewModel: Error fetching reminders: \(reminderError.localizedDescription)")
                                return
                            }

                            // Step 4: Use batch to delete user_stores and reminders
                            // Now allowed because shared group no longer exists
                            let batch = self.db.batch()

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
                                    print("StoresViewModel: Error deleting user_stores and reminders: \(error.localizedDescription)")
                                } else {
                                    print("StoresViewModel: Successfully deleted \(userStoreDocuments.count) user_stores and \(reminderSnapshot?.documents.count ?? 0) reminders")
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
                print("StoresViewModel: Error updating sort order: \(error.localizedDescription)")
            } else {
                print("StoresViewModel: Sort order updated successfully")
            }
        }
    }

    /// Toggle notifications for a specific user store
    func toggleNotifications(for userStoreItem: UserStoreItem) {
        let newValue = !userStoreItem.notificationsEnabled
        print("StoresViewModel: Toggling notifications for store '\(userStoreItem.store.name)' to \(newValue)")

        db.collection("user_stores").document(userStoreItem.id).updateData([
            "notificationsEnabled": newValue
        ]) { error in
            if let error = error {
                print("StoresViewModel: Error toggling notifications: \(error.localizedDescription)")
            } else {
                print("StoresViewModel: Notifications toggled successfully to \(newValue)")
            }
        }
    }

    deinit {
        // Clean up listeners when ViewModel is destroyed
        storesListener?.remove()
        removeAllReminderCountListeners()
    }
}
