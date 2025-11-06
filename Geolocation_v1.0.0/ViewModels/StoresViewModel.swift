// swift
// File: `Geolocation_v1.0.0/ViewModels/StoresViewModel.swift`

import Foundation
import FirebaseFirestore
import FirebaseAuth

class StoresViewModel: ObservableObject {
    private let db = Firestore.firestore()
    @Published var stores: [Store] = []
    @Published var allStores: [Store] = [] // All available stores for adding
    @Published var isLoading: Bool = false
    @Published var errorMessage: String = ""

    /// Fetch only stores that the current user has added to their list
    func fetchUserStores() {
        guard let currentUserEmail = Auth.auth().currentUser?.email else {
            print("StoresViewModel: No authenticated user")
            return
        }

        isLoading = true
        print("StoresViewModel: Fetching stores for user: \(currentUserEmail)")

        // First, get the user's userId from their email
        db.collection("users")
            .whereField("email", isEqualTo: currentUserEmail)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }

                if let error = error {
                    print("StoresViewModel: Error fetching user: \(error.localizedDescription)")
                    self.errorMessage = "Error fetching user: \(error.localizedDescription)"
                    self.isLoading = false
                    return
                }

                guard let userDoc = snapshot?.documents.first,
                      let userId = userDoc.data()["userId"] as? String else {
                    print("StoresViewModel: User not found")
                    self.errorMessage = "User not found"
                    self.isLoading = false
                    return
                }

                print("StoresViewModel: Found userId: \(userId)")
                self.fetchUserStoresById(userId: userId)
            }
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
                    self.stores = []
                    return
                }

                print("StoresViewModel: Found \(documents.count) user stores")

                self.stores = documents.compactMap { doc -> Store? in
                    let data = doc.data()
                    guard let storeId = data["storeId"] as? String,
                          let storeName = data["storeName"] as? String,
                          let storeAddress = data["storeAddress"] as? String else {
                        print("StoresViewModel: Missing fields in user_store document")
                        return nil
                    }

                    return Store(id: storeId, name: storeName, address: storeAddress)
                }

                print("StoresViewModel: Loaded \(self.stores.count) stores for user")
            }
    }

    /// Fetch all available stores from the stores collection
    func fetchAllStores() {
        print("StoresViewModel: Fetching all available stores")

        db.collection("stores").getDocuments { [weak self] snapshot, error in
            guard let self = self else { return }

            if let error = error {
                print("StoresViewModel: Error fetching all stores: \(error.localizedDescription)")
                return
            }

            guard let documents = snapshot?.documents else {
                print("StoresViewModel: No stores in database")
                return
            }

            self.allStores = documents.compactMap { doc -> Store? in
                let data = doc.data()
                guard let name = data["name"] as? String,
                      let address = data["address"] as? String else {
                    return nil
                }
                return Store(id: doc.documentID, name: name, address: address)
            }

            print("StoresViewModel: Loaded \(self.allStores.count) available stores")
        }
    }

    /// Add a store to the current user's list
    func addStoreToUser(store: Store) {
        guard let currentUserEmail = Auth.auth().currentUser?.email else {
            errorMessage = "No authenticated user"
            return
        }

        print("StoresViewModel: Adding store '\(store.name)' to user")

        // Get userId first
        db.collection("users")
            .whereField("email", isEqualTo: currentUserEmail)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }

                if let error = error {
                    self.errorMessage = "Error: \(error.localizedDescription)"
                    return
                }

                guard let userDoc = snapshot?.documents.first,
                      let userId = userDoc.data()["userId"] as? String else {
                    self.errorMessage = "User not found"
                    return
                }

                // Check if store is already added
                self.db.collection("user_stores")
                    .whereField("userId", isEqualTo: userId)
                    .whereField("storeId", isEqualTo: store.id)
                    .getDocuments { snapshot, error in
                        if let documents = snapshot?.documents, !documents.isEmpty {
                            self.errorMessage = "Store already added"
                            return
                        }

                        // Add store to user's list
                        let userStore: [String: Any] = [
                            "userId": userId,
                            "storeId": store.id,
                            "storeName": store.name,
                            "storeAddress": store.address,
                            "addedAt": Date().timeIntervalSince1970
                        ]

                        self.db.collection("user_stores").addDocument(data: userStore) { error in
                            if let error = error {
                                print("StoresViewModel: Error adding store: \(error.localizedDescription)")
                                self.errorMessage = "Error adding store: \(error.localizedDescription)"
                            } else {
                                print("StoresViewModel: Store added successfully")
                            }
                        }
                    }
            }
    }

    /// Remove a store from the current user's list
    func removeStoreFromUser(store: Store) {
        guard let currentUserEmail = Auth.auth().currentUser?.email else {
            return
        }

        db.collection("users")
            .whereField("email", isEqualTo: currentUserEmail)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }

                guard let userDoc = snapshot?.documents.first,
                      let userId = userDoc.data()["userId"] as? String else {
                    return
                }

                // Find and delete the user_store document
                self.db.collection("user_stores")
                    .whereField("userId", isEqualTo: userId)
                    .whereField("storeId", isEqualTo: store.id)
                    .getDocuments { snapshot, error in
                        guard let documents = snapshot?.documents else { return }

                        for document in documents {
                            document.reference.delete { error in
                                if let error = error {
                                    print("StoresViewModel: Error removing store: \(error.localizedDescription)")
                                } else {
                                    print("StoresViewModel: Store removed successfully")
                                }
                            }
                        }
                    }
            }
    }
}
