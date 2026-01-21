//
//  ReminderViewModel.swift
//  Geolocation_v1.0.0
//
//  Created by Claude on 11/6/24.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

class ReminderViewModel: ObservableObject {
    private let db = Firestore.firestore()
    @Published var reminders: [Reminder] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String = ""

    /// Fetch reminders for a specific user_store document
    /// - Parameters:
    ///   - userStoreId: The user_store ID to fetch reminders for
    ///   - sharedFromName: If this is a shared store, the name of the user who shared it (to populate sharedFrom on reminders)
    func fetchReminders(for userStoreId: String, sharedFromName: String? = nil) {
        isLoading = true
        print("ReminderViewModel: Fetching reminders for userStoreId: \(userStoreId), sharedFromName: \(sharedFromName ?? "nil")")

        db.collection("reminders")
            .whereField("userStoreId", isEqualTo: userStoreId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }

                DispatchQueue.main.async {
                    self.isLoading = false

                    if let error = error {
                        print("ReminderViewModel: Error fetching reminders: \(error.localizedDescription)")
                        print("ReminderViewModel: Full error: \(error)")
                        self.errorMessage = "Error fetching reminders: \(error.localizedDescription)"
                        return
                    }

                    guard let documents = snapshot?.documents else {
                        print("ReminderViewModel: No reminders found (nil documents)")
                        self.reminders = []
                        return
                    }

                    print("ReminderViewModel: Found \(documents.count) reminder documents")

                    let fetchedReminders = documents.compactMap { doc -> Reminder? in
                        let data = doc.data()
                        print("ReminderViewModel: Processing document \(doc.documentID): \(data)")

                        guard let userStoreId = data["userStoreId"] as? String,
                              let title = data["title"] as? String,
                              let isDone = data["isDone"] as? Bool,
                              let createdAt = data["createdAt"] as? TimeInterval else {
                            print("ReminderViewModel: Missing fields in reminder document \(doc.documentID)")
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
                            sharedWith: sharedWith
                        )
                    }

                    // Sort by createdAt in memory (oldest first)
                    self.reminders = fetchedReminders.sorted { $0.createdAt < $1.createdAt }

                    print("ReminderViewModel: Successfully loaded \(self.reminders.count) reminders")
                }
            }
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

        print("ReminderViewModel: Adding reminder '\(title)' for userStoreId: \(userStoreId), sharedWith: \(sharedWith ?? []), sharedFromName: \(sharedFromName ?? "nil"), currentUserName: \(currentUserName ?? "nil")")

        var reminderData: [String: Any] = [
            "userStoreId": userStoreId,
            "title": title,
            "isDone": false,
            "createdAt": Date().timeIntervalSince1970
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
                    print("ReminderViewModel: Error adding reminder: \(error.localizedDescription)")
                    self?.errorMessage = "Error adding reminder: \(error.localizedDescription)"
                } else {
                    print("ReminderViewModel: Reminder added successfully (isShared: \(isSharedStore))")
                }
            }
        }
    }

    /// Toggle reminder isDone status - syncs across all linked shared reminders
    func toggleReminder(_ reminder: Reminder) {
        print("ReminderViewModel: Toggling reminder '\(reminder.title)'")

        let newIsDone = !reminder.isDone

        // If this reminder has a sharedReminderId, sync toggle across all linked reminders
        if let sharedReminderId = reminder.sharedReminderId {
            print("ReminderViewModel: Syncing toggle across shared reminders with sharedReminderId: \(sharedReminderId)")

            db.collection("reminders")
                .whereField("sharedReminderId", isEqualTo: sharedReminderId)
                .getDocuments { [weak self] snapshot, error in
                    guard let self = self else { return }

                    if let error = error {
                        print("ReminderViewModel: Error finding linked reminders: \(error.localizedDescription)")
                        // Fall back to updating just this reminder
                        self.updateSingleReminder(reminder.id, isDone: newIsDone)
                        return
                    }

                    guard let documents = snapshot?.documents, !documents.isEmpty else {
                        // No linked reminders found, update just this one
                        self.updateSingleReminder(reminder.id, isDone: newIsDone)
                        return
                    }

                    // Batch update all linked reminders
                    let batch = self.db.batch()
                    for doc in documents {
                        batch.updateData(["isDone": newIsDone], forDocument: doc.reference)
                    }

                    batch.commit { error in
                        DispatchQueue.main.async {
                            if let error = error {
                                print("ReminderViewModel: Error syncing toggle: \(error.localizedDescription)")
                            } else {
                                print("ReminderViewModel: Synced toggle across \(documents.count) linked reminders")
                            }
                        }
                    }
                }
        } else {
            // No sharing, just update this reminder
            updateSingleReminder(reminder.id, isDone: newIsDone)
        }
    }

    private func updateSingleReminder(_ reminderId: String, isDone: Bool) {
        db.collection("reminders").document(reminderId).updateData([
            "isDone": isDone
        ]) { error in
            DispatchQueue.main.async {
                if let error = error {
                    print("ReminderViewModel: Error toggling reminder: \(error.localizedDescription)")
                } else {
                    print("ReminderViewModel: Reminder toggled successfully")
                }
            }
        }
    }

    /// Delete a reminder - syncs deletion across all linked shared reminders
    func deleteReminder(_ reminder: Reminder) {
        print("ReminderViewModel: Deleting reminder '\(reminder.title)'")

        // If this reminder has a sharedReminderId, delete all linked reminders
        if let sharedReminderId = reminder.sharedReminderId {
            print("ReminderViewModel: Syncing deletion across shared reminders with sharedReminderId: \(sharedReminderId)")

            db.collection("reminders")
                .whereField("sharedReminderId", isEqualTo: sharedReminderId)
                .getDocuments { [weak self] snapshot, error in
                    guard let self = self else { return }

                    if let error = error {
                        print("ReminderViewModel: Error finding linked reminders: \(error.localizedDescription)")
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

                    batch.commit { error in
                        DispatchQueue.main.async {
                            if let error = error {
                                print("ReminderViewModel: Error syncing deletion: \(error.localizedDescription)")
                            } else {
                                print("ReminderViewModel: Synced deletion across \(documents.count) linked reminders")
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
        db.collection("reminders").document(reminderId).delete { error in
            DispatchQueue.main.async {
                if let error = error {
                    print("ReminderViewModel: Error deleting reminder: \(error.localizedDescription)")
                } else {
                    print("ReminderViewModel: Reminder deleted successfully")
                }
            }
        }
    }
}
