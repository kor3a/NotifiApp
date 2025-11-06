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
    func fetchReminders(for userStoreId: String) {
        isLoading = true
        print("ReminderViewModel: Fetching reminders for userStoreId: \(userStoreId)")

        db.collection("reminders")
            .whereField("userStoreId", isEqualTo: userStoreId)
            .order(by: "createdAt", descending: false)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }

                self.isLoading = false

                if let error = error {
                    print("ReminderViewModel: Error fetching reminders: \(error.localizedDescription)")
                    self.errorMessage = "Error fetching reminders: \(error.localizedDescription)"
                    return
                }

                guard let documents = snapshot?.documents else {
                    print("ReminderViewModel: No reminders found")
                    self.reminders = []
                    return
                }

                print("ReminderViewModel: Found \(documents.count) reminders")

                self.reminders = documents.compactMap { doc -> Reminder? in
                    let data = doc.data()
                    guard let userStoreId = data["userStoreId"] as? String,
                          let title = data["title"] as? String,
                          let isDone = data["isDone"] as? Bool,
                          let createdAt = data["createdAt"] as? TimeInterval else {
                        print("ReminderViewModel: Missing fields in reminder document")
                        return nil
                    }

                    return Reminder(
                        id: doc.documentID,
                        userStoreId: userStoreId,
                        title: title,
                        isDone: isDone,
                        createdAt: createdAt
                    )
                }

                print("ReminderViewModel: Loaded \(self.reminders.count) reminders")
            }
    }

    /// Add a new reminder
    func addReminder(userStoreId: String, title: String) {
        guard !title.isEmpty else {
            errorMessage = "Reminder title cannot be empty"
            return
        }

        print("ReminderViewModel: Adding reminder '\(title)' for userStoreId: \(userStoreId)")

        let reminderData: [String: Any] = [
            "userStoreId": userStoreId,
            "title": title,
            "isDone": false,
            "createdAt": Date().timeIntervalSince1970
        ]

        db.collection("reminders").addDocument(data: reminderData) { [weak self] error in
            if let error = error {
                print("ReminderViewModel: Error adding reminder: \(error.localizedDescription)")
                self?.errorMessage = "Error adding reminder: \(error.localizedDescription)"
            } else {
                print("ReminderViewModel: Reminder added successfully")
            }
        }
    }

    /// Toggle reminder isDone status
    func toggleReminder(_ reminder: Reminder) {
        print("ReminderViewModel: Toggling reminder '\(reminder.title)'")

        db.collection("reminders").document(reminder.id).updateData([
            "isDone": !reminder.isDone
        ]) { error in
            if let error = error {
                print("ReminderViewModel: Error toggling reminder: \(error.localizedDescription)")
            } else {
                print("ReminderViewModel: Reminder toggled successfully")
            }
        }
    }

    /// Delete a reminder
    func deleteReminder(_ reminder: Reminder) {
        print("ReminderViewModel: Deleting reminder '\(reminder.title)'")

        db.collection("reminders").document(reminder.id).delete { error in
            if let error = error {
                print("ReminderViewModel: Error deleting reminder: \(error.localizedDescription)")
            } else {
                print("ReminderViewModel: Reminder deleted successfully")
            }
        }
    }
}
