// swift
// File: `Geolocation_v1.0.0/ViewModels/StoresViewModel.swift`

import Foundation
import FirebaseFirestore
import FirebaseAuth
import FirebaseStorage
import Combine

class StoresViewModel: ObservableObject {
    private let db = Firestore.firestore()
    let sessionManager = UserSessionManager.shared // Changed from private to internal
    @Published var userStoreItems: [UserStoreItem] = [] // User's stores with user_store IDs
    @Published var allStores: [Store] = [] // All available stores for adding
    @Published var isLoading: Bool = false
    @Published var isLoadingAllStores: Bool = false
    /// False until the store listener has answered for the first time — the
    /// gap between this view model being created and `isLoading` being set,
    /// which is a frame the screen would otherwise draw as "No stores yet".
    /// Stores are only ever empty for real once this is true.
    @Published var hasLoadedStores: Bool = false
    @Published var errorMessage: String = ""

    // Store the listener registration so we can remove it later
    private var storesListener: ListenerRegistration?

    // The userId `storesListener` was registered for, or nil whenever there is no
    // listener worth reusing. Repeat fetches for the same user reuse the live
    // listener; a different user, a torn-down listener, or one that errored all
    // leave this nil (or mismatched) so the next fetch rebuilds.
    private var listeningForUserId: String?

    // Reminder count listeners for real-time updates (keyed by reminderStoreId)
    private var reminderCountListeners: [String: ListenerRegistration] = [:]

    // Shared status listeners to detect when recipients leave (keyed by owner's userStoreId)
    private var sharedStatusListeners: [String: ListenerRegistration] = [:]

    // Source store listeners — watch the original owner's user_store document for merged stores.
    // When the owner deletes their store, B's app detects it here and cleans up B's merged store
    // locally (no cross-user Firestore write permissions needed).
    private var sourceStoreListeners: [String: ListenerRegistration] = [:]

    // Flag to prevent listener from overwriting during manual sort
    private var isManuallyReordering = false

    private var cancellables = Set<AnyCancellable>()

    init() {
        TutorialManager.shared.$isActive
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isActive in
                if isActive {
                    self?.loadTutorialMockData()
                } else {
                    self?.clearTutorialMockData()
                    self?.fetchUserStores()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Tutorial Mock Data

    private func loadTutorialMockData() {
        storesListener?.remove()
        storesListener = nil
        listeningForUserId = nil
        removeAllReminderCountListeners()
        removeAllSharedStatusListeners()
        removeAllSourceStoreListeners()
        isLoading = false
        hasLoadedStores = true
        userStoreItems = TutorialMockData.stores
    }

    private func clearTutorialMockData() {
        storesListener?.remove()
        storesListener = nil
        listeningForUserId = nil
        removeAllReminderCountListeners()
        removeAllSharedStatusListeners()
        removeAllSourceStoreListeners()
        userStoreItems = []
    }

    /// Fetch only stores that the current user has added to their list
    func fetchUserStores() {
        guard !TutorialManager.shared.isActive else {
            loadTutorialMockData()
            return
        }

        guard let userId = sessionManager.currentUser?.userId else {
            #if DEBUG
            print("StoresViewModel: No user data available in session, waiting...")
            #endif
            // Don't show error immediately - user data might still be loading
            isLoading = false
            return
        }

        // HomeView, StoresView and MapView each call in from onAppear, so a cold
        // launch asks two or three times over. The snapshot listener is already
        // live and delivering realtime updates by then — rebuilding it re-reads
        // user_stores, re-registers a reminder-count listener per store and
        // re-runs the whole geofence allocation, only to land on the data we
        // already have. Reuse it instead.
        //
        // Anything that should rebuild still does: a different signed-in user
        // fails the id check, and the tutorial transitions and a listener error
        // all clear `listeningForUserId` first.
        if storesListener != nil, listeningForUserId == userId {
            #if DEBUG
            print("StoresViewModel: Already listening for \(userId) — reusing live listener")
            #endif
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
        removeAllSourceStoreListeners()

        // Add new snapshot listener and store the registration
        listeningForUserId = userId
        storesListener = db.collection("user_stores")
            .whereField("userId", isEqualTo: userId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }

                self.isLoading = false
                // Set on every outcome, errors included: a failed read should
                // land the user on the screen with its error, not hold them on
                // the loading screen forever.
                self.hasLoadedStores = true

                if let error = error {
                    #if DEBUG
                    print("StoresViewModel: Error fetching user stores: \(error.localizedDescription)")
                    #endif
                    self.errorMessage = "Error fetching stores: \(error.localizedDescription)"
                    // Release the reuse claim. A signed-out session loses read
                    // permission and errors here; without this the next fetch
                    // would reuse a dead listener and never recover.
                    self.listeningForUserId = nil
                    return
                }

                guard let documents = snapshot?.documents else {
                    #if DEBUG
                    print("StoresViewModel: No stores found for user")
                    #endif
                    self.userStoreItems = []
                    self.removeAllReminderCountListeners()
                    self.removeAllSharedStatusListeners()
                    self.removeAllSourceStoreListeners()
                    return
                }

                #if DEBUG
                print("StoresViewModel: Found \(documents.count) user stores")
                #endif

                // Preserve existing reminder counts so they aren't reset to 0
                // when the snapshot fires (e.g. after adding a new store)
                var existingReminderCounts: [String: Int] = [:]
                for item in self.userStoreItems {
                    existingReminderCounts[item.reminderStoreId] = item.store.reminderCount
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
                    let mergedFromOwnStore = data["mergedFromOwnStore"] as? Bool ?? false

                    // Determine which ID to use for fetching reminders.
                    // Owners always use their own user_store ID even if sourceUserStoreId is set
                    // (the merge flow sets sourceUserStoreId for tracking without changing owner's reminders).
                    let reminderStoreId = permission == .owner
                        ? userStoreId
                        : (sourceUserStoreId ?? sharedStoreGroupId ?? userStoreId)
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
                        notificationsEnabled: notificationsEnabled,
                        mergedFromOwnStore: mergedFromOwnStore
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

                // Push the updated store list to the home screen widget
                WidgetDataStore.shared.updateWidgetData(from: self.userStoreItems)

                // Refresh stale sharedFromName values by looking up current names
                self.refreshSharedFromNames(for: self.userStoreItems)

                // Set up real-time listeners for reminder counts
                self.setupReminderCountListeners(for: reminderStoreIds)

                // Set up real-time listeners for shared store recipients
                self.setupSharedStatusListeners(for: tempUserStoreItems)

                // Watch the source user_store for each merged store — detects owner deletion
                self.setupSourceStoreListeners(for: tempUserStoreItems)

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
            let itemReminderStoreId = item.reminderStoreId

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
                    notificationsEnabled: item.notificationsEnabled,
                    mergedFromOwnStore: item.mergedFromOwnStore
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

    /// Watch the source (owner's) user_store document for each merged store B participates in.
    /// When the owner deletes their store, B's app detects it locally and runs cleanup using
    /// B's own credentials — no cross-user Firestore write permissions required.
    ///
    /// Two shapes qualify:
    ///   • Legacy merged stores — `permission == .owner` with a `sourceUserStoreId`. B kept
    ///     their own reminders, so cleanup only severs the link.
    ///   • Merged-into-a-shared-list stores — `mergedFromOwnStore`, where the reminders
    ///     live on the owner's store, so cleanup has to hand the list back. The owner's app
    ///     does the same hand-back; both write the same deterministic document IDs, so
    ///     whichever runs (or both) the result is identical.
    private func setupSourceStoreListeners(for items: [UserStoreItem]) {
        let mergedItems = items.filter {
            $0.sourceUserStoreId != nil && ($0.permission == .owner || $0.mergedFromOwnStore)
        }
        let activeSourceIds = Set(mergedItems.compactMap { $0.sourceUserStoreId })

        // Remove listeners for source stores no longer in the list
        let currentIds = Set(sourceStoreListeners.keys)
        for id in currentIds.subtracting(activeSourceIds) {
            sourceStoreListeners[id]?.remove()
            sourceStoreListeners.removeValue(forKey: id)
        }

        for item in mergedItems {
            guard let sourceUserStoreId = item.sourceUserStoreId else { continue }
            guard sourceStoreListeners[sourceUserStoreId] == nil else { continue }

            let mergedUserStoreId = item.id
            let ownerUserId = item.sharedFromId ?? ""
            let ownerName = item.sharedFromName ?? ""
            let needsHandBack = item.mergedFromOwnStore

            let listener = db.collection("user_stores").document(sourceUserStoreId)
                .addSnapshotListener { [weak self] snapshot, error in
                    guard let self = self, let snapshot = snapshot else { return }
                    // React only when the source store document is deleted
                    guard !snapshot.exists else { return }

                    // Owner deleted their store — clean up our merged store using our own credentials.
                    self.sourceStoreListeners[sourceUserStoreId]?.remove()
                    self.sourceStoreListeners.removeValue(forKey: sourceUserStoreId)

                    if needsHandBack {
                        // Our reminders live on the store that just disappeared: copy the
                        // list back into our own store before it is deleted with it.
                        self.restoreMergedStoreToOwnStore(
                            userStoreId: mergedUserStoreId,
                            sourceUserStoreId: sourceUserStoreId,
                            departingOwnerName: ownerName,
                            completion: {}
                        )
                    } else {
                        self.clearMergedStoreSharing(
                            mergedUserStoreId: mergedUserStoreId,
                            ownerUserId: ownerUserId,
                            ownerName: ownerName
                        )
                    }
                }
            sourceStoreListeners[sourceUserStoreId] = listener
        }
    }

    private func removeAllSourceStoreListeners() {
        for (_, listener) in sourceStoreListeners {
            listener.remove()
        }
        sourceStoreListeners.removeAll()
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
        guard !TutorialManager.shared.isActive else { return }
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
                    "sortOrder": sortOrder,
                    // Explicitly mark self-created stores as owned. Other users' devices key
                    // off this field when deciding whether a shared store may be deleted, and
                    // a missing value previously caused merged owner stores to be misclassified
                    // as deletable recipients.
                    "permission": "owner"
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
        guard !TutorialManager.shared.isActive else { return }
        #if DEBUG
        print("StoresViewModel: Removing user_store document: \(userStoreItem.id)")
        #endif

        // Drop this store's custom background too — its key is the user_store
        // document id, which is gone for good, so the photo would otherwise sit
        // on disk unreachable.
        BackgroundPreferences.shared.reset(.reminders(storeId: userStoreItem.id))

        // Remove from local array immediately for smooth UI
        userStoreItems.removeAll { $0.id == userStoreItem.id }
        // Reflect removal in the home screen widget immediately
        WidgetDataStore.shared.updateWidgetData(from: userStoreItems)

        // Use the permission information already available in userStoreItem
        // instead of fetching the document again (which could fail and leave orphaned reminders)
        let permission = userStoreItem.permission
        let sharedGroupId = userStoreItem.sharedStoreGroupId
        let isRecipient = userStoreItem.sharedFromName != nil // If sharedFromName is set, user is a recipient

        // Check if this is a shared store with Can Edit permission and a shared group.
        // !isRecipient ensures only the original creator of the group (not co-editors) deletes
        // the entire group. Co-editors (who have sharedFromName set) are treated as recipients
        // and only remove their own copy.
        if permission == .edit, let sharedGroupId = sharedGroupId, !isRecipient {
            // Original creator of "Can Edit" group - delete entire group for all users
            self.deleteSharedStoreGroup(sharedGroupId: sharedGroupId, userStoreItem: userStoreItem)
        } else if isRecipient {
            // Recipient leaving (view-only or co-editor) - only remove from their account
            self.deleteRecipientUserStore(userStoreItem: userStoreItem)
        } else {
            // Owner without sharing, or owner with view-only recipients - delete store
            self.deleteSingleUserStore(userStoreItem: userStoreItem)
        }
    }

    private func deleteSingleUserStore(userStoreItem: UserStoreItem) {
        #if DEBUG
        print("StoresViewModel: Deleting single user_store: \(userStoreItem.id)")
        #endif

        let ownerUserStoreId = userStoreItem.id

        // Capture db and user info before async operations so that critical
        // Firestore cleanup still runs even if the ViewModel is deallocated
        // (e.g. the user navigates away immediately after deleting).
        let db = self.db
        let currentUser = self.sessionManager.currentUser

        // Delete the user_store document
        db.collection("user_stores").document(ownerUserStoreId).delete { [weak self] error in
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

        // The store's own reminders are deleted LAST. Recipients who folded their own
        // store into this one have the list handed back to them first, and that can only
        // happen while these documents still exist.
        db.collection("reminders")
            .whereField("userStoreId", isEqualTo: ownerUserStoreId)
            .getDocuments { [weak self] snapshot, error in
                if let error = error {
                    #if DEBUG
                    print("StoresViewModel: Error fetching reminders: \(error.localizedDescription)")
                    #endif
                }

                let documents = snapshot?.documents ?? []

                // `preservePhotos` is set when a recipient was handed a copy of this list:
                // their copies reference the same Storage files, so deleting the files
                // would leave them with broken images.
                let deleteOwnReminders: (Bool) -> Void = { preservePhotos in
                    guard !documents.isEmpty else { return }

                    // Clean up all attached photos from Storage before deleting the
                    // reminder docs, otherwise the files are left orphaned.
                    if !preservePhotos {
                        var photoURLs = Set<String>()
                        for doc in documents {
                            if let urls = doc.data()["photoURLs"] as? [String] {
                                photoURLs.formUnion(urls)
                            }
                        }
                        for url in photoURLs {
                            Storage.storage().reference(forURL: url).delete { error in
                                #if DEBUG
                                if let error = error {
                                    print("StoresViewModel: Failed to delete photo from storage: \(error.localizedDescription)")
                                }
                                #endif
                            }
                        }
                    }

                    let batch = db.batch()
                    for doc in documents {
                        batch.deleteDocument(doc.reference)
                    }

                    batch.commit { error in
                        #if DEBUG
                        if let error = error {
                            print("StoresViewModel: Error deleting reminders: \(error.localizedDescription)")
                        } else {
                            print("StoresViewModel: Deleted \(documents.count) reminders")
                        }
                        #endif
                    }
                }

                guard let self = self else {
                    deleteOwnReminders(false)
                    return
                }

                self.cleanupRecipientUserStores(
                    ownerUserStoreId: ownerUserStoreId,
                    storeName: userStoreItem.store.name,
                    currentUserId: currentUser?.userId,
                    currentUserName: currentUser?.name,
                    ownerReminderDocs: documents,
                    completion: deleteOwnReminders
                )
            }
    }

    /// Clean up every `user_store` that pointed at a store its owner just deleted, then
    /// notify the people behind them.
    ///
    /// Recipients fall into three groups:
    ///   • Handed back — they owned this store before merging it into the deleted one, so
    ///     they keep it: the list is copied into their store and ownership restored.
    ///   • Regular `edit`/`view` recipients — their copy only ever mirrored the owner's
    ///     store, so it is deleted.
    ///   • Legacy merged stores (no permission field) — the recipient's own store, which
    ///     is only unlinked, never deleted.
    ///
    /// `completion` is handed `true` when a hand-back happened, meaning the owner's photo
    /// files are now referenced by someone else's list and must not be deleted.
    ///
    /// Firestore rules allow the original sharer to update or delete recipient
    /// user_stores (via the sharedFromEmail / sharedFrom userId checks in rules).
    private func cleanupRecipientUserStores(
        ownerUserStoreId: String,
        storeName: String,
        currentUserId: String?,
        currentUserName: String?,
        ownerReminderDocs: [QueryDocumentSnapshot],
        completion: @escaping (Bool) -> Void
    ) {
        let db = self.db

        db.collection("user_stores")
            .whereField("sourceUserStoreId", isEqualTo: ownerUserStoreId)
            .getDocuments { [weak self] snapshot, error in
                if let error = error {
                    #if DEBUG
                    print("StoresViewModel: Error fetching recipient user_stores: \(error.localizedDescription)")
                    #endif
                    completion(false)
                    return
                }

                let recipientDocs = snapshot?.documents ?? []
                guard !recipientDocs.isEmpty else {
                    completion(false)
                    return
                }

                #if DEBUG
                print("StoresViewModel: Cleaning up \(recipientDocs.count) recipient user_stores for deleted owner store")
                #endif

                // Recipients who merged their OWN store into this one get it back rather
                // than losing it — they owned that store before the merge.
                let handBackDocs = recipientDocs.filter {
                    ($0.data()["mergedFromOwnStore"] as? Bool) == true
                }
                let dependentDocs = recipientDocs.filter {
                    ($0.data()["mergedFromOwnStore"] as? Bool) != true
                }

                // Separate legacy merged stores (recipient keeps ownership of the store)
                // from regular shared stores (recipient only has a dependent copy).
                // Only explicit "edit"/"view" recipients have a dependent copy that should be
                // deleted. A missing permission means the recipient owns their own store (a
                // merged store created via addStoreToUser, which never writes a permission
                // field) — those must NOT be deleted, only unlinked.
                let regularDocs = dependentDocs.filter {
                    let permission = $0.data()["permission"] as? String
                    return permission == "edit" || permission == "view"
                }
                let mergedDocs = dependentDocs.filter {
                    let permission = $0.data()["permission"] as? String
                    return !(permission == "edit" || permission == "view")
                }

                // Delete regular recipient user_stores in a batch
                if !regularDocs.isEmpty {
                    let batch = db.batch()
                    for doc in regularDocs {
                        batch.deleteDocument(doc.reference)
                    }
                    batch.commit { error in
                        #if DEBUG
                        if let error = error {
                            print("StoresViewModel: Error deleting recipient user_stores: \(error.localizedDescription)")
                        } else {
                            print("StoresViewModel: Deleted \(regularDocs.count) regular recipient user_stores")
                        }
                        #endif
                    }
                }

                // For legacy merged stores: clear sharing metadata and remove owner's reminders.
                // The recipient's store is their own — don't delete it, just unlink it.
                let ownerUserId = currentUserId ?? ""
                let ownerName = currentUserName ?? ""
                for doc in mergedDocs {
                    self?.clearMergedStoreSharing(
                        mergedUserStoreId: doc.documentID,
                        ownerUserId: ownerUserId,
                        ownerName: ownerName
                    )
                }

                // Notify each recipient that the owner deleted the shared store
                let notifyRecipients = {
                    guard let self = self,
                          let currentUserId = currentUserId,
                          let currentUserName = currentUserName else { return }

                    let recipientId: (QueryDocumentSnapshot) -> String? = { $0.data()["userId"] as? String }
                    let regularIds = regularDocs.compactMap(recipientId).filter { $0 != currentUserId }
                    let mergedIds = mergedDocs.compactMap(recipientId).filter { $0 != currentUserId }
                    let handBackIds = handBackDocs.compactMap(recipientId).filter { $0 != currentUserId }
                    let allRecipientIds = regularIds + mergedIds + handBackIds
                    guard !allRecipientIds.isEmpty else { return }

                    self.fetchUsersNames(userIds: allRecipientIds) { [weak self] nameMap in
                        guard let self = self else { return }
                        let notify: (String, String) -> Void = { userId, message in
                            self.sendStoreDeletionMessage(
                                currentUserId: currentUserId,
                                currentUserName: currentUserName,
                                recipientId: userId,
                                recipientName: nameMap[userId] ?? "Unknown",
                                message: message
                            )
                        }
                        for id in regularIds {
                            notify(id, "\(currentUserName) deleted \(storeName), which was shared with you. The store has been removed from your account.")
                        }
                        for id in mergedIds {
                            notify(id, "\(currentUserName) deleted \(storeName). Their shared items have been removed from your list.")
                        }
                        for id in handBackIds {
                            notify(id, "\(currentUserName) deleted the shared \(storeName). It is back in your list as your own store.")
                        }
                    }
                }

                guard !handBackDocs.isEmpty else {
                    notifyRecipients()
                    completion(false)
                    return
                }

                // Copy the list into each hand-back recipient's own store and restore
                // their ownership, before the owner's reminder documents are deleted.
                let batch = db.batch()
                for doc in handBackDocs {
                    for reminder in ownerReminderDocs {
                        let data = reminder.data()
                        guard let title = data["title"] as? String else { continue }

                        var newData: [String: Any] = [
                            "userStoreId": doc.documentID,
                            "title": title,
                            "isDone": data["isDone"] as? Bool ?? false,
                            "createdAt": data["createdAt"] as? TimeInterval ?? Date().timeIntervalSince1970,
                            "isShared": false
                        ]
                        if let v = data["quantity"]  { newData["quantity"] = v }
                        if let v = data["category"]  { newData["category"] = v }
                        if let v = data["sortOrder"] { newData["sortOrder"] = v }
                        if let v = data["photoURLs"] { newData["photoURLs"] = v }

                        // Deterministic ID so this copy converges with the one the
                        // recipient's own app may make (see `setupSourceStoreListeners`)
                        // instead of duplicating every item.
                        batch.setData(
                            newData,
                            forDocument: db.collection("reminders").document("\(doc.documentID)_\(reminder.documentID)")
                        )
                    }

                    batch.updateData([
                        "permission": "owner",
                        "sourceUserStoreId":  FieldValue.delete(),
                        "mergedFromOwnStore": FieldValue.delete(),
                        "sharedFrom":         FieldValue.delete(),
                        "sharedFromEmail":    FieldValue.delete(),
                        "sharedFromName":     FieldValue.delete(),
                        "sharedWith":         FieldValue.arrayRemove([ownerName])
                    ], forDocument: doc.reference)
                }

                batch.commit { error in
                    #if DEBUG
                    if let error = error {
                        print("StoresViewModel: Error handing merged stores back: \(error.localizedDescription)")
                    } else {
                        print("StoresViewModel: Handed \(handBackDocs.count) merged stores back to their owners")
                    }
                    #endif
                    notifyRecipients()
                    // The handed-back copies reference the same photo files, so the
                    // owner's Storage objects have to survive this deletion.
                    completion(error == nil)
                }
            }
    }

    private func deleteRecipientUserStore(userStoreItem: UserStoreItem) {
        #if DEBUG
        print("StoresViewModel: Deleting recipient's shared user_store: \(userStoreItem.id)")
        #endif

        // Capture current user info before the async delete
        let currentUser = sessionManager.currentUser
        let currentUserName = currentUser?.name

        // Merged store, current shape: the user owned this store before merging it into
        // someone else's shared list, so they are an `.edit` participant on that list and
        // the items live on the other user's store. Deleting this user_store the regular
        // way would leave them with nothing — hand the store back instead.
        if userStoreItem.mergedFromOwnStore, let sourceUserStoreId = userStoreItem.sourceUserStoreId {
            let ownerName = userStoreItem.sharedFromName ?? ""

            restoreMergedStoreToOwnStore(
                userStoreId: userStoreItem.id,
                sourceUserStoreId: sourceUserStoreId,
                departingOwnerName: ownerName
            ) { [weak self] in
                // Only now strip this user from the other side, so the copy above is
                // taken from the list as it stood while they were still part of it.
                guard let self = self, let currentUserName = currentUserName else { return }
                self.updateOwnerRemindersAfterRecipientLeaves(
                    ownerUserStoreId: sourceUserStoreId,
                    recipientName: currentUserName
                )
                self.updateOwnerUserStoreAfterRecipientLeaves(
                    ownerUserStoreId: sourceUserStoreId,
                    recipientName: currentUserName
                )
            }

            // Notify the user whose list this was merged into
            if let currentUser = currentUser,
               let ownerId = userStoreItem.sharedFromId,
               !ownerId.isEmpty,
               let ownerDisplayName = userStoreItem.sharedFromName {
                sendStoreDeletionMessage(
                    currentUserId: currentUser.userId,
                    currentUserName: currentUser.name,
                    recipientId: ownerId,
                    recipientName: ownerDisplayName,
                    message: "\(currentUser.name) disconnected from the shared \(userStoreItem.store.name). Their shared items have been removed from your list."
                )
            }
            return
        }

        // Merged-store case: the current user owns this store (permission == .owner) but it
        // was merged with a shared store from someone else. Don't delete their own store —
        // just unlink the sharing relationship and clean up the owner's side.
        if userStoreItem.permission == .owner {
            let ownerName = userStoreItem.sharedFromName ?? ""
            let ownerUserId = userStoreItem.sharedFromId ?? ""

            // Remove shared-from metadata from this user's store so the shared icon disappears
            clearMergedStoreSharing(
                mergedUserStoreId: userStoreItem.id,
                ownerUserId: ownerUserId,
                ownerName: ownerName
            )

            // Clean up the original owner's store as well
            if let currentUserName = currentUserName,
               let sourceUserStoreId = userStoreItem.sourceUserStoreId {
                updateOwnerRemindersAfterRecipientLeaves(
                    ownerUserStoreId: sourceUserStoreId,
                    recipientName: currentUserName
                )
                updateOwnerUserStoreAfterRecipientLeaves(
                    ownerUserStoreId: sourceUserStoreId,
                    recipientName: currentUserName
                )
            }

            // Notify the original owner
            if let currentUser = currentUser,
               let ownerId = userStoreItem.sharedFromId,
               !ownerId.isEmpty,
               let ownerDisplayName = userStoreItem.sharedFromName {
                sendStoreDeletionMessage(
                    currentUserId: currentUser.userId,
                    currentUserName: currentUser.name,
                    recipientId: ownerId,
                    recipientName: ownerDisplayName,
                    message: "\(currentUser.name) disconnected from the shared \(userStoreItem.store.name). Their shared items have been removed from your list."
                )
            }
            return
        }

        // Regular (non-merged) recipient: delete their user_store document
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

                // Notify the owner that the recipient removed the shared store
                if let currentUser = currentUser,
                   let ownerId = userStoreItem.sharedFromId,
                   let ownerName = userStoreItem.sharedFromName {
                    let message: String
                    if userStoreItem.permission == .edit {
                        message = "\(currentUser.name) left the shared \(userStoreItem.store.name) store. The store is no longer shared with them."
                    } else {
                        message = "\(currentUser.name) removed \(userStoreItem.store.name) from their account. The store is no longer shared with them."
                    }
                    self?.sendStoreDeletionMessage(
                        currentUserId: currentUser.userId,
                        currentUserName: currentUser.name,
                        recipientId: ownerId,
                        recipientName: ownerName,
                        message: message
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

                    // Case 2: Reminder was created by the recipient and added to the owner's store.
                    // Delete it entirely now that the recipient is leaving — it was their item.
                    if sharedFrom == recipientName {
                        batch.deleteDocument(doc.reference)
                        updatedCount += 1
                        continue
                    }

                    // Case 1: Reminder created by owner, shared with recipient
                    // Remove the recipient from sharedWith
                    if sharedWith.contains(recipientName) {
                        sharedWith.removeAll { $0 == recipientName }
                        updatedCount += 1

                        if sharedWith.isEmpty {
                            // No more sharing recipients, clear shared status completely
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

    /// Hand a merged store back to the user who owned it before the merge.
    ///
    /// Every path that ends a merged share funnels through here — the merged user leaving,
    /// the sharer revoking their access (`ShareStoreView`), and the sharer deleting the
    /// shared store. Copies are written under deterministic document IDs so that two of
    /// those paths racing produces one list, not two.
    ///
    /// After `MessagingService.mergeStoreReminders` the two lists are one, and the
    /// reminder documents hang off the other user's `user_store`. Leaving the share the
    /// regular way (deleting this user's `user_store`) would therefore take the whole
    /// list with it — including everything this user had before they ever merged. So
    /// copy the shared list into their own store, drop the sharing metadata and restore
    /// `owner` permission. Runs entirely under the leaving user's own credentials.
    ///
    /// The copy is deliberately the *whole* list: a merge folds both users' items into a
    /// single set with no reliable way to tell them apart afterwards, which is the same
    /// reason `clearMergedStoreSharing` never deletes anything either.
    func restoreMergedStoreToOwnStore(
        userStoreId: String,
        sourceUserStoreId: String,
        departingOwnerName: String,
        completion: @escaping () -> Void
    ) {
        let db = self.db

        let restoreOwnership = {
            db.collection("user_stores").document(userStoreId).updateData([
                "permission": "owner",
                "sourceUserStoreId":  FieldValue.delete(),
                "mergedFromOwnStore": FieldValue.delete(),
                "sharedFrom":         FieldValue.delete(),
                "sharedFromEmail":    FieldValue.delete(),
                "sharedFromName":     FieldValue.delete(),
                "sharedWith":         FieldValue.arrayRemove([departingOwnerName])
            ]) { error in
                #if DEBUG
                if let error = error {
                    print("StoresViewModel: Error restoring merged store \(userStoreId): \(error.localizedDescription)")
                } else {
                    print("StoresViewModel: Restored merged store \(userStoreId) to standalone ownership")
                }
                #endif
                completion()
            }
        }

        db.collection("reminders")
            .whereField("userStoreId", isEqualTo: sourceUserStoreId)
            .getDocuments { snapshot, error in
                if let error = error {
                    #if DEBUG
                    print("StoresViewModel: Error fetching shared reminders to restore: \(error.localizedDescription)")
                    #endif
                    // Still hand the store back — an empty store beats a store that
                    // points at a list this user no longer belongs to.
                    restoreOwnership()
                    return
                }

                let documents = snapshot?.documents ?? []
                guard !documents.isEmpty else {
                    restoreOwnership()
                    return
                }

                let batch = db.batch()
                var restored = 0

                for doc in documents {
                    let data = doc.data()
                    guard let title = data["title"] as? String else { continue }

                    var newData: [String: Any] = [
                        "userStoreId": userStoreId,
                        "title": title,
                        "isDone": data["isDone"] as? Bool ?? false,
                        "createdAt": data["createdAt"] as? TimeInterval ?? Date().timeIntervalSince1970,
                        "isShared": false
                    ]
                    if let v = data["quantity"]  { newData["quantity"] = v }
                    if let v = data["category"]  { newData["category"] = v }
                    if let v = data["sortOrder"] { newData["sortOrder"] = v }
                    if let v = data["photoURLs"] { newData["photoURLs"] = v }

                    // Deterministic ID so this copy converges with the one the other
                    // user's app may make when they delete the store, rather than
                    // duplicating every item.
                    batch.setData(
                        newData,
                        forDocument: db.collection("reminders").document("\(userStoreId)_\(doc.documentID)")
                    )
                    restored += 1
                }

                guard restored > 0 else {
                    restoreOwnership()
                    return
                }

                batch.commit { error in
                    #if DEBUG
                    if let error = error {
                        print("StoresViewModel: Error restoring reminders for \(userStoreId): \(error.localizedDescription)")
                    } else {
                        print("StoresViewModel: Restored \(restored) reminders into \(userStoreId)")
                    }
                    #endif
                    restoreOwnership()
                }
            }
    }

    /// Handles unlinking a merged store from its former co-owner.
    ///
    /// This is only ever called for a recipient who owns their OWN store
    /// (`permission == .owner`) — they had that store before merging with the other
    /// owner. So the store is NEVER deleted here, and the recipient's reminders are
    /// NEVER deleted: the merge re-attributes the recipient's own duplicate items to
    /// the other owner (`sharedFromId == ownerUserId`), making them indistinguishable
    /// from items the other owner contributed. Deleting on that basis would destroy the
    /// recipient's own data and can empty/remove the store entirely.
    ///
    /// Instead we sever ONLY the link to the departing owner:
    ///   • Reminders attributed to the departing owner are un-attributed (they become the
    ///     recipient's own items) and the owner's name is removed from any `sharedWith`.
    ///   • The user_store keeps existing; its link fields to the owner are cleared and the
    ///     owner's name is removed from `sharedWith`, so the recipient stays the primary
    ///     owner — still sharing the store with anyone else they had shared it with.
    private func clearMergedStoreSharing(mergedUserStoreId: String, ownerUserId: String, ownerName: String) {
        let db = self.db

        // Fetch ALL reminders in the recipient's merged store (not just isShared==true,
        // in case any slipped through)
        db.collection("reminders")
            .whereField("userStoreId", isEqualTo: mergedUserStoreId)
            .getDocuments { snapshot, error in
                if let error = error {
                    #if DEBUG
                    print("StoresViewModel: Error fetching merged store reminders for cleanup: \(error.localizedDescription)")
                    #endif
                    return
                }

                let allDocs = snapshot?.documents ?? []

                let batch = db.batch()

                for doc in allDocs {
                    let data = doc.data()
                    let sharedFromId = data["sharedFromId"] as? String
                    let sharedFromName = data["sharedFrom"] as? String
                    var sharedWith = data["sharedWith"] as? [String] ?? []

                    // Was this item attributed to the departing owner? (Either a copy the
                    // owner contributed, or one of the recipient's own duplicates the merge
                    // re-attributed.) Either way, keep it as the recipient's own item now.
                    let attributedToOwner = (sharedFromId == ownerUserId && !ownerUserId.isEmpty)
                        || (sharedFromId == nil && sharedFromName == ownerName && !ownerName.isEmpty)

                    var updates: [String: Any] = [:]

                    if attributedToOwner {
                        updates["sharedFrom"] = FieldValue.delete()
                        updates["sharedFromId"] = FieldValue.delete()
                    }

                    if sharedWith.contains(ownerName) {
                        sharedWith.removeAll { $0 == ownerName }
                        updates["sharedWith"] = sharedWith.isEmpty ? FieldValue.delete() : sharedWith
                    }

                    // Recompute the shared flag: still shared only if shared with someone
                    // else, or still attributed from someone other than the departing owner.
                    let stillSharedWithOthers = !sharedWith.isEmpty
                    let stillSharedFromOther = !attributedToOwner && (sharedFromName != nil)
                    if (data["isShared"] as? Bool) == true
                        && !stillSharedWithOthers
                        && !stillSharedFromOther {
                        updates["isShared"] = false
                    }

                    if !updates.isEmpty {
                        batch.updateData(updates, forDocument: doc.reference)
                    }
                }

                // Always KEEP the recipient's store; just sever the link to the departing
                // owner. Remove only the owner's name from `sharedWith` so any independent
                // shares the recipient has (e.g. with another user) survive.
                let unlinkUserStore = {
                    db.collection("user_stores").document(mergedUserStoreId).updateData([
                        "sourceUserStoreId": FieldValue.delete(),
                        "sharedFrom":        FieldValue.delete(),
                        "sharedFromEmail":   FieldValue.delete(),
                        "sharedFromName":    FieldValue.delete(),
                        "sharedWith":        FieldValue.arrayRemove([ownerName])
                    ]) { error in
                        #if DEBUG
                        if let error = error {
                            print("StoresViewModel: Error unlinking merged store \(mergedUserStoreId): \(error.localizedDescription)")
                        } else {
                            print("StoresViewModel: Unlinked merged store \(mergedUserStoreId) from \(ownerName) — store kept")
                        }
                        #endif
                    }
                }

                if allDocs.isEmpty {
                    unlinkUserStore()
                } else {
                    batch.commit { error in
                        #if DEBUG
                        if let error = error {
                            print("StoresViewModel: Error cleaning merged store reminders \(mergedUserStoreId): \(error.localizedDescription)")
                            return
                        }
                        #endif
                        unlinkUserStore()
                    }
                }
            }
    }

    private func deleteSharedStoreGroup(sharedGroupId: String, userStoreItem: UserStoreItem) {
        #if DEBUG
        print("StoresViewModel: Deleting shared store group: \(sharedGroupId)")
        #endif

        // Notify co-editors asynchronously before proceeding with deletion.
        // Their user_stores share the same sharedStoreGroupId.
        if let currentUser = sessionManager.currentUser {
            db.collection("user_stores")
                .whereField("sharedStoreGroupId", isEqualTo: sharedGroupId)
                .getDocuments { [weak self] snapshot, _ in
                    guard let self = self else { return }

                    let coEditorDocs = snapshot?.documents.filter {
                        $0.data()["userId"] as? String != currentUser.userId
                    } ?? []
                    let coEditorIds = coEditorDocs.compactMap { $0.data()["userId"] as? String }
                    guard !coEditorIds.isEmpty else { return }

                    self.fetchUsersNames(userIds: coEditorIds) { nameMap in
                        for coEditorId in coEditorIds {
                            let coEditorName = nameMap[coEditorId] ?? "Unknown"
                            self.sendStoreDeletionMessage(
                                currentUserId: currentUser.userId,
                                currentUserName: currentUser.name,
                                recipientId: coEditorId,
                                recipientName: coEditorName,
                                message: "\(currentUser.name) deleted the shared \(userStoreItem.store.name) store. It has been removed from your account."
                            )
                        }
                    }
                }
        }

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

    // MARK: - Deletion Messaging Helpers

    /// Send a message to a user notifying them about a store deletion.
    /// Finds or creates a conversation with the recipient, then sends the message.
    private func sendStoreDeletionMessage(
        currentUserId: String,
        currentUserName: String,
        recipientId: String,
        recipientName: String,
        message: String
    ) {
        MessagingService.shared.findOrCreateConversation(
            currentUserId: currentUserId,
            currentUserName: currentUserName,
            otherUserId: recipientId,
            otherUserName: recipientName
        ) { result in
            switch result {
            case .success(let conversation):
                MessagingService.shared.sendMessage(
                    conversationId: conversation.id,
                    senderId: currentUserId,
                    senderName: currentUserName,
                    content: message,
                    completion: { _ in }
                )
            case .failure(let error):
                #if DEBUG
                print("StoresViewModel: Failed to send store deletion message to \(recipientName): \(error.localizedDescription)")
                #endif
            }
        }
    }

    /// Look up the display names for a list of user IDs.
    /// Queries the users collection using `whereField("userId", in:)` in chunks of 10.
    /// Calls completion on the main queue with a userId -> name mapping.
    private func fetchUsersNames(userIds: [String], completion: @escaping ([String: String]) -> Void) {
        guard !userIds.isEmpty else {
            completion([:])
            return
        }

        // Firestore `in` queries support at most 10 values per call
        let chunks = stride(from: 0, to: userIds.count, by: 10).map {
            Array(userIds[$0..<min($0 + 10, userIds.count)])
        }

        var nameMap: [String: String] = [:]
        let group = DispatchGroup()

        for chunk in chunks {
            group.enter()
            db.collection("users")
                .whereField("userId", in: chunk)
                .getDocuments { snapshot, _ in
                    for doc in snapshot?.documents ?? [] {
                        let data = doc.data()
                        if let userId = data["userId"] as? String,
                           let name = data["name"] as? String {
                            nameMap[userId] = name
                        }
                    }
                    group.leave()
                }
        }

        group.notify(queue: .main) {
            completion(nameMap)
        }
    }

    /// Sort stores by reminder count (highest first) and persist the new order.
    /// This is a one-shot action: the resulting order is written to Firestore as the
    /// stores' permanent sortOrder, exactly as if the user had dragged them into place.
    func sortByReminderCount() {
        let sorted = userStoreItems.sorted { $0.store.reminderCount > $1.store.reminderCount }
        reorderStores(newOrder: sorted)
    }

    /// Reorder stores using a fully-specified new order (used by Float view drag-to-reorder)
    func reorderStores(newOrder: [UserStoreItem]) {
        isManuallyReordering = true
        userStoreItems = newOrder
        WidgetDataStore.shared.updateWidgetData(from: userStoreItems)

        let batch = db.batch()
        for (index, item) in newOrder.enumerated() {
            let docRef = db.collection("user_stores").document(item.id)
            batch.updateData(["sortOrder": index], forDocument: docRef)
        }

        batch.commit { [weak self] error in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self?.isManuallyReordering = false
            }
            #if DEBUG
            if let error = error {
                print("StoresViewModel: Error updating sort order (float): \(error.localizedDescription)")
            } else {
                print("StoresViewModel: Float sort order updated successfully")
            }
            #endif
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
        removeAllSourceStoreListeners()
    }
}
