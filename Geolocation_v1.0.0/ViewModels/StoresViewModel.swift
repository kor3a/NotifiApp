// swift
// File: `Geolocation_v1.0.0/ViewModels/StoresViewModel.swift`

import Foundation
import FirebaseFirestore

class StoresViewModel: ObservableObject {
    private let db = Firestore.firestore()
    @Published var stores: [Store] = []

    func fetchData() {
        db.collection("stores").addSnapshotListener { snapshot, error in
            if let error = error {
                print("Error fetching stores: \(error.localizedDescription)")
                return
            }
            
            guard let documents = snapshot?.documents else {
                print("No documents")
                return
            }
            
            print("Found \(documents.count) documents")
            
            self.stores = documents.compactMap { (queryDocumentSnapshot) -> Store? in
                let data = queryDocumentSnapshot.data()
                print("Processing document: \(queryDocumentSnapshot.documentID)")
                print("Document data: \(data)")

                guard let name = data["name"] as? String,
                      let address = data["address"] as? String else {
                    print("Missing required fields in document: \(queryDocumentSnapshot.documentID)")
                    return nil
                }
                
                print("Successfully created store: \(name)")
                return Store(name: name, address: address)
            }
            
            print("Total stores loaded: \(self.stores.count)")
        }
    }
}
