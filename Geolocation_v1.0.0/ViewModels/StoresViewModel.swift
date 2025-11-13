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
        db.collection("user_stores")
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
                    group.enter()

                    // Fetch reminder count for this user_store
                    self.db.collection("reminders")
                        .whereField("userStoreId", isEqualTo: userStoreId)
                        .whereField("isDone", isEqualTo: false)
                        .getDocuments { snapshot, error in
                            defer { group.leave() }

                            let reminderCount = snapshot?.documents.count ?? 0
                            print("StoresViewModel: Store '\(storeName)' has \(reminderCount) active reminders")

                            var store = Store(id: storeId, name: storeName, address: storeAddress)
                            store.reminderCount = reminderCount
                            store.sortOrder = sortOrder
                            let userStoreItem = UserStoreItem(id: userStoreId, store: store)
                            tempUserStoreItems.append(userStoreItem)
                        }
                }

                // When all reminder counts are fetched, update the published property
                group.notify(queue: .main) {
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
                return Store(id: doc.documentID, name: name, address: address)
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
        guard let userId = sessionManager.currentUser?.userId else {
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
                let userStore: [String: Any] = [
                    "userId": userId,
                    "storeId": store.id,
                    "storeName": store.name,
                    "storeAddress": store.address,
                    "addedAt": Date().timeIntervalSince1970,
                    "sortOrder": sortOrder
                ]

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

        db.collection("user_stores").document(userStoreItem.id).delete { error in
            if let error = error {
                print("StoresViewModel: Error removing store: \(error.localizedDescription)")
            } else {
                print("StoresViewModel: Store removed successfully")
            }
        }
    }

    /// Reorder stores when user drags and drops
    func moveStore(from source: IndexSet, to destination: Int) {
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

        batch.commit { error in
            if let error = error {
                print("StoresViewModel: Error updating sort order: \(error.localizedDescription)")
            } else {
                print("StoresViewModel: Sort order updated successfully")
            }
        }
    }
}
