// swift
// File: `Geolocation_v1.0.0/ViewModels/StoresViewModel.swift`

import Foundation
import FirebaseFirestore
import FirebaseAuth

class StoresViewModel: ObservableObject {
    private let db = Firestore.firestore()
    private let sessionManager = UserSessionManager.shared
    @Published var userStoreItems: [UserStoreItem] = [] // User's stores with user_store IDs
    @Published var allStores: [Store] = [] // All available stores for adding
    @Published var isLoading: Bool = false
    @Published var isLoadingAllStores: Bool = false
    @Published var errorMessage: String = ""

    // Store the listener registration so we can remove it later
    private var storesListener: ListenerRegistration?

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
        // Remove existing listener to prevent duplicates
        storesListener?.remove()

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
                    return
                }

                print("StoresViewModel: Found \(documents.count) user stores")

                // Use DispatchGroup to coordinate fetching reminder counts
                let group = DispatchGroup()
                var tempUserStoreItems: [UserStoreItem] = []

                for doc in documents {
                    let data = doc.data()
                    guard let storeId = data["storeId"] as? String,
                          let storeName = data["storeName"] as? String,
                          let storeAddress = data["storeAddress"] as? String else {
                        print("StoresViewModel: Missing fields in user_store document")
                        continue
                    }

                    let userStoreId = doc.documentID
                    let sortOrder = data["sortOrder"] as? Int
                    let latitude = data["latitude"] as? Double
                    let longitude = data["longitude"] as? Double
                    group.enter()

                    // Fetch reminder count for this user_store
                    self.db.collection("reminders")
                        .whereField("userStoreId", isEqualTo: userStoreId)
                        .whereField("isDone", isEqualTo: false)
                        .getDocuments { snapshot, error in
                            defer { group.leave() }

                            let reminderCount = snapshot?.documents.count ?? 0
                            print("StoresViewModel: Store '\(storeName)' has \(reminderCount) active reminders")

                            var store = Store(
                                id: storeId,
                                name: storeName,
                                address: storeAddress,
                                reminderCount: reminderCount,
                                sortOrder: sortOrder,
                                latitude: latitude,
                                longitude: longitude
                            )
                            let userStoreItem = UserStoreItem(id: userStoreId, store: store)
                            tempUserStoreItems.append(userStoreItem)
                        }
                }

                // When all reminder counts are fetched, update the published property
                group.notify(queue: .main) {
                    // Skip updating if we're manually reordering (to prevent race conditions)
                    guard !self.isManuallyReordering else {
                        print("StoresViewModel: Skipping listener update during manual reorder")
                        return
                    }

                    // Sort by sortOrder, putting items without sortOrder at the end
                    self.userStoreItems = tempUserStoreItems.sorted { item1, item2 in
                        let order1 = item1.store.sortOrder ?? Int.max
                        let order2 = item2.store.sortOrder ?? Int.max
                        return order1 < order2
                    }
                    print("StoresViewModel: Loaded \(self.userStoreItems.count) stores with reminder counts")
                }
            }
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
                guard let name = data["name"] as? String,
                      let address = data["address"] as? String else {
                    return nil
                }
                let latitude = data["latitude"] as? Double
                let longitude = data["longitude"] as? Double
                return Store(
                    id: doc.documentID,
                    name: name,
                    address: address,
                    reminderCount: 0,
                    sortOrder: nil,
                    latitude: latitude,
                    longitude: longitude
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
    func addStoreToUser(store: Store) {
        guard let userId = sessionManager.currentUser?.userId,
              let userEmail = sessionManager.currentUser?.email else {
            DispatchQueue.main.async {
                self.errorMessage = "No user data available"
            }
            return
        }

        print("StoresViewModel: Adding store '\(store.name)' to user")

        // Check if store is already added
        db.collection("user_stores")
            .whereField("userId", isEqualTo: userId)
            .whereField("storeId", isEqualTo: store.id)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }

                if let documents = snapshot?.documents, !documents.isEmpty {
                    DispatchQueue.main.async {
                        self.errorMessage = "Store already added"
                    }
                    return
                }

                // Add store to user's list
                // Assign sortOrder as the count of current stores (to append at the end)
                let sortOrder = self.userStoreItems.count
                var userStore: [String: Any] = [
                    "userId": userId,
                    "userEmail": userEmail,
                    "storeId": store.id,
                    "storeName": store.name,
                    "storeAddress": store.address,
                    "addedAt": Date().timeIntervalSince1970,
                    "sortOrder": sortOrder
                ]

                // Add coordinates if available
                if let latitude = store.latitude {
                    userStore["latitude"] = latitude
                }
                if let longitude = store.longitude {
                    userStore["longitude"] = longitude
                }

                self.db.collection("user_stores").addDocument(data: userStore) { error in
                    if let error = error {
                        print("StoresViewModel: Error adding store: \(error.localizedDescription)")
                        DispatchQueue.main.async {
                            self.errorMessage = "Error adding store: \(error.localizedDescription)"
                        }
                    } else {
                        print("StoresViewModel: Store added successfully")
                    }
                }
            }
    }

    /// Remove a store from the current user's list
    func removeStoreFromUser(userStoreItem: UserStoreItem) {
        print("StoresViewModel: Removing user_store document: \(userStoreItem.id)")

        // Remove from local array immediately for smooth UI
        userStoreItems.removeAll { $0.id == userStoreItem.id }

        // Delete from Firebase
        db.collection("user_stores").document(userStoreItem.id).delete { error in
            if let error = error {
                print("StoresViewModel: Error removing store: \(error.localizedDescription)")
                // TODO: Could add error handling to restore the item if delete fails
            } else {
                print("StoresViewModel: Store removed successfully")
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

    /// Share a store with another user by email
    func shareStore(userStoreItem: UserStoreItem, recipientEmail: String, completion: @escaping (Bool, String?) -> Void) {
        guard let senderUserId = sessionManager.currentUser?.userId else {
            completion(false, "No user data available")
            return
        }

        print("StoresViewModel: Sharing store '\(userStoreItem.store.name)' with \(recipientEmail)")

        // First, find the recipient user by email
        db.collection("users")
            .whereField("email", isEqualTo: recipientEmail)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }

                if let error = error {
                    print("StoresViewModel: Error finding recipient: \(error.localizedDescription)")
                    completion(false, "Error finding recipient: \(error.localizedDescription)")
                    return
                }

                guard let recipientDocument = snapshot?.documents.first else {
                    print("StoresViewModel: No user found with email: \(recipientEmail)")
                    completion(false, "No user found with this email address. Make sure the recipient has an account.")
                    return
                }

                let recipientUserId = recipientDocument.data()["userId"] as? String ?? recipientDocument.documentID

                // Check if user is trying to share with themselves
                if recipientUserId == senderUserId {
                    completion(false, "You cannot share a store with yourself.")
                    return
                }

                print("StoresViewModel: Found recipient user: \(recipientUserId)")

                // Check if recipient already has this store
                self.db.collection("user_stores")
                    .whereField("userId", isEqualTo: recipientUserId)
                    .whereField("storeId", isEqualTo: userStoreItem.store.id)
                    .getDocuments { snapshot, error in
                        if let documents = snapshot?.documents, !documents.isEmpty {
                            completion(false, "This user already has this store.")
                            return
                        }

                        // Create new user_store for recipient
                        self.createSharedUserStore(
                            recipientUserId: recipientUserId,
                            recipientEmail: recipientEmail,
                            userStoreItem: userStoreItem,
                            completion: completion
                        )
                    }
            }
    }

    private func createSharedUserStore(recipientUserId: String, recipientEmail: String, userStoreItem: UserStoreItem, completion: @escaping (Bool, String?) -> Void) {
        // Get the recipient's current store count for sortOrder
        db.collection("user_stores")
            .whereField("userId", isEqualTo: recipientUserId)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }

                let sortOrder = snapshot?.documents.count ?? 0

                // Create user_store document for recipient
                var newUserStore: [String: Any] = [
                    "userId": recipientUserId,
                    "userEmail": recipientEmail,
                    "storeId": userStoreItem.store.id,
                    "storeName": userStoreItem.store.name,
                    "storeAddress": userStoreItem.store.address,
                    "addedAt": Date().timeIntervalSince1970,
                    "sortOrder": sortOrder,
                    "sharedFrom": self.sessionManager.currentUser?.userId ?? "",
                    "sharedAt": Date().timeIntervalSince1970
                ]

                // Add coordinates if available
                if let latitude = userStoreItem.store.latitude {
                    newUserStore["latitude"] = latitude
                }
                if let longitude = userStoreItem.store.longitude {
                    newUserStore["longitude"] = longitude
                }

                // Add the new user_store document
                self.db.collection("user_stores").addDocument(data: newUserStore) { error in
                    if let error = error {
                        print("StoresViewModel: Error creating shared user_store: \(error.localizedDescription)")
                        completion(false, "Error sharing store: \(error.localizedDescription)")
                        return
                    }

                    print("StoresViewModel: User_store created successfully")

                    // Now copy all active reminders
                    self.copyReminders(
                        fromUserStoreId: userStoreItem.id,
                        toUserStoreId: nil, // We'll fetch it
                        recipientUserId: recipientUserId,
                        completion: completion
                    )
                }
            }
    }

    private func copyReminders(fromUserStoreId: String, toUserStoreId: String?, recipientUserId: String, completion: @escaping (Bool, String?) -> Void) {
        // First, fetch all active reminders from the source user_store
        db.collection("reminders")
            .whereField("userStoreId", isEqualTo: fromUserStoreId)
            .whereField("isDone", isEqualTo: false)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }

                if let error = error {
                    print("StoresViewModel: Error fetching reminders to copy: \(error.localizedDescription)")
                    completion(false, "Store shared, but error copying reminders: \(error.localizedDescription)")
                    return
                }

                guard let reminderDocuments = snapshot?.documents else {
                    print("StoresViewModel: No reminders to copy")
                    completion(true, "Store shared successfully with no reminders.")
                    return
                }

                // If we need to find the new user_store ID, fetch it
                if toUserStoreId == nil {
                    // We need to find the newly created user_store
                    self.db.collection("user_stores")
                        .whereField("userId", isEqualTo: recipientUserId)
                        .order(by: "addedAt", descending: true)
                        .limit(to: 1)
                        .getDocuments { snapshot, error in
                            guard let newUserStoreId = snapshot?.documents.first?.documentID else {
                                completion(false, "Store shared, but couldn't find recipient's store to copy reminders.")
                                return
                            }

                            self.performReminderCopy(
                                reminderDocuments: reminderDocuments,
                                toUserStoreId: newUserStoreId,
                                completion: completion
                            )
                        }
                } else {
                    self.performReminderCopy(
                        reminderDocuments: reminderDocuments,
                        toUserStoreId: toUserStoreId!,
                        completion: completion
                    )
                }
            }
    }

    private func performReminderCopy(reminderDocuments: [QueryDocumentSnapshot], toUserStoreId: String, completion: @escaping (Bool, String?) -> Void) {
        print("StoresViewModel: Copying \(reminderDocuments.count) reminders")

        let batch = db.batch()

        for doc in reminderDocuments {
            let data = doc.data()
            guard let title = data["title"] as? String else { continue }

            let newReminder: [String: Any] = [
                "userStoreId": toUserStoreId,
                "title": title,
                "isDone": false,
                "createdAt": Date().timeIntervalSince1970
            ]

            let newDocRef = self.db.collection("reminders").document()
            batch.setData(newReminder, forDocument: newDocRef)
        }

        batch.commit { error in
            if let error = error {
                print("StoresViewModel: Error copying reminders: \(error.localizedDescription)")
                completion(false, "Store shared, but error copying reminders: \(error.localizedDescription)")
            } else {
                print("StoresViewModel: Successfully copied \(reminderDocuments.count) reminders")
                completion(true, "Store and \(reminderDocuments.count) reminder(s) shared successfully!")
            }
        }
    }

    deinit {
        // Clean up listener when ViewModel is destroyed
        storesListener?.remove()
    }
}
