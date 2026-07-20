//
//  ReminderHistoryViewModel.swift
//  Geolocation_v1.0.0
//
//  Created by James Jeon on 7/20/26.
//

import Foundation
import FirebaseFirestore

class ReminderHistoryViewModel: ObservableObject {
    private let db = Firestore.firestore()
    @Published var entries: [ReminderHistoryEntry] = []
    @Published var isLoading: Bool = false
    private var listener: ListenerRegistration?

    deinit {
        listener?.remove()
    }

    /// Fetch history entries for a store (real-time listener). Sorted newest
    /// first client-side so no composite Firestore index is required.
    func fetchHistory(for userStoreId: String) {
        isLoading = true
        listener?.remove()

        listener = db.collection("reminder_history")
            .whereField("userStoreId", isEqualTo: userStoreId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }

                DispatchQueue.main.async {
                    self.isLoading = false

                    if let error = error {
                        #if DEBUG
                        print("ReminderHistoryViewModel: Error fetching history: \(error.localizedDescription)")
                        #endif
                        return
                    }

                    guard let documents = snapshot?.documents else {
                        self.entries = []
                        return
                    }

                    self.entries = documents.compactMap { doc -> ReminderHistoryEntry? in
                        let data = doc.data()
                        guard let userStoreId = data["userStoreId"] as? String,
                              let title = data["title"] as? String,
                              let checkedOffAt = data["checkedOffAt"] as? TimeInterval else {
                            return nil
                        }
                        return ReminderHistoryEntry(
                            id: doc.documentID,
                            userStoreId: userStoreId,
                            title: title,
                            checkedOffAt: checkedOffAt,
                            checkedOffBy: data["checkedOffBy"] as? String,
                            checkedOffById: data["checkedOffById"] as? String,
                            createdBy: data["createdBy"] as? String,
                            createdById: data["createdById"] as? String,
                            createdAt: data["createdAt"] as? TimeInterval,
                            deletedAt: data["deletedAt"] as? TimeInterval,
                            quantity: data["quantity"] as? Int,
                            photoURLs: data["photoURLs"] as? [String],
                            category: data["category"] as? String
                        )
                    }.sorted { $0.checkedOffAt > $1.checkedOffAt }

                    #if DEBUG
                    print("ReminderHistoryViewModel: Loaded \(self.entries.count) history entries")
                    #endif
                }
            }
    }
}
