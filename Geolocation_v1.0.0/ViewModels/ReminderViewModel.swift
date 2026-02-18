//
//  ReminderViewModel.swift
//  Geolocation_v1.0.0
//
//  Created by Claude on 11/6/24.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
import FirebaseStorage
import UIKit

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
        #if DEBUG
        print("ReminderViewModel: Fetching reminders for userStoreId: \(userStoreId), sharedFromName: \(sharedFromName ?? "nil")")
        #endif

        db.collection("reminders")
            .whereField("userStoreId", isEqualTo: userStoreId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }

                DispatchQueue.main.async {
                    self.isLoading = false

                    if let error = error {
                        #if DEBUG
                        print("ReminderViewModel: Error fetching reminders: \(error.localizedDescription)")
                        print("ReminderViewModel: Full error: \(error)")
                        #endif
                        self.errorMessage = "Error fetching reminders: \(error.localizedDescription)"
                        return
                    }

                    guard let documents = snapshot?.documents else {
                        #if DEBUG
                        print("ReminderViewModel: No reminders found (nil documents)")
                        #endif
                        self.reminders = []
                        return
                    }

                    #if DEBUG
                    print("ReminderViewModel: Found \(documents.count) reminder documents")
                    #endif

                    let fetchedReminders = documents.compactMap { doc -> Reminder? in
                        let data = doc.data()
                        #if DEBUG
                        print("ReminderViewModel: Processing document \(doc.documentID): \(data)")
                        #endif

                        guard let userStoreId = data["userStoreId"] as? String,
                              let title = data["title"] as? String,
                              let isDone = data["isDone"] as? Bool,
                              let createdAt = data["createdAt"] as? TimeInterval else {
                            #if DEBUG
                            print("ReminderViewModel: Missing fields in reminder document \(doc.documentID)")
                            #endif
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

                        let photoURLs = data["photoURLs"] as? [String]

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
                            sharedWith: sharedWith,
                            photoURLs: photoURLs
                        )
                    }

                    // Sort by createdAt in memory (oldest first)
                    self.reminders = fetchedReminders.sorted { $0.createdAt < $1.createdAt }

                    #if DEBUG
                    print("ReminderViewModel: Successfully loaded \(self.reminders.count) reminders")
                    #endif
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

        #if DEBUG
        print("ReminderViewModel: Adding reminder '\(title)' for userStoreId: \(userStoreId), sharedWith: \(sharedWith ?? []), sharedFromName: \(sharedFromName ?? "nil"), currentUserName: \(currentUserName ?? "nil")")
        #endif

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
                    #if DEBUG
                    print("ReminderViewModel: Error adding reminder: \(error.localizedDescription)")
                    #endif
                    self?.errorMessage = "Error adding reminder: \(error.localizedDescription)"
                } else {
                    #if DEBUG
                    print("ReminderViewModel: Reminder added successfully (isShared: \(isSharedStore))")
                    #endif
                }
            }
        }
    }

    /// Toggle reminder isDone status - syncs across all linked shared reminders
    func toggleReminder(_ reminder: Reminder) {
        #if DEBUG
        print("ReminderViewModel: Toggling reminder '\(reminder.title)'")
        #endif

        let newIsDone = !reminder.isDone

        // If this reminder has a sharedReminderId, sync toggle across all linked reminders
        if let sharedReminderId = reminder.sharedReminderId {
            #if DEBUG
            print("ReminderViewModel: Syncing toggle across shared reminders with sharedReminderId: \(sharedReminderId)")
            #endif

            db.collection("reminders")
                .whereField("sharedReminderId", isEqualTo: sharedReminderId)
                .getDocuments { [weak self] snapshot, error in
                    guard let self = self else { return }

                    if let error = error {
                        #if DEBUG
                        print("ReminderViewModel: Error finding linked reminders: \(error.localizedDescription)")
                        #endif
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
                                #if DEBUG
                                print("ReminderViewModel: Error syncing toggle: \(error.localizedDescription)")
                                #endif
                            } else {
                                #if DEBUG
                                print("ReminderViewModel: Synced toggle across \(documents.count) linked reminders")
                                #endif
                            }
                        }
                    }
                }
        } else {
            // No sharing, just update this reminder
            updateSingleReminder(reminder.id, isDone: newIsDone)
        }
    }

    /// Update reminder title - syncs across all linked shared reminders
    func updateReminderTitle(_ reminder: Reminder, newTitle: String) {
        let trimmedTitle = newTitle.trimmingCharacters(in: .whitespaces)
        guard !trimmedTitle.isEmpty, trimmedTitle != reminder.title else { return }

        #if DEBUG
        print("ReminderViewModel: Updating title for reminder '\(reminder.title)' to '\(trimmedTitle)'")
        #endif

        if let sharedReminderId = reminder.sharedReminderId {
            db.collection("reminders")
                .whereField("sharedReminderId", isEqualTo: sharedReminderId)
                .getDocuments { [weak self] snapshot, error in
                    guard let self = self else { return }

                    if let error = error {
                        #if DEBUG
                        print("ReminderViewModel: Error finding linked reminders for title update: \(error.localizedDescription)")
                        #endif
                        self.updateSingleReminderTitle(reminder.id, title: trimmedTitle)
                        return
                    }

                    guard let documents = snapshot?.documents, !documents.isEmpty else {
                        self.updateSingleReminderTitle(reminder.id, title: trimmedTitle)
                        return
                    }

                    let batch = self.db.batch()
                    for doc in documents {
                        batch.updateData(["title": trimmedTitle], forDocument: doc.reference)
                    }

                    batch.commit { error in
                        DispatchQueue.main.async {
                            if let error = error {
                                #if DEBUG
                                print("ReminderViewModel: Error syncing title update: \(error.localizedDescription)")
                                #endif
                            } else {
                                #if DEBUG
                                print("ReminderViewModel: Synced title update across \(documents.count) linked reminders")
                                #endif
                            }
                        }
                    }
                }
        } else {
            updateSingleReminderTitle(reminder.id, title: trimmedTitle)
        }
    }

    private func updateSingleReminderTitle(_ reminderId: String, title: String) {
        db.collection("reminders").document(reminderId).updateData([
            "title": title
        ]) { error in
            DispatchQueue.main.async {
                if let error = error {
                    #if DEBUG
                    print("ReminderViewModel: Error updating reminder title: \(error.localizedDescription)")
                    #endif
                } else {
                    #if DEBUG
                    print("ReminderViewModel: Reminder title updated successfully")
                    #endif
                }
            }
        }
    }

    private func updateSingleReminder(_ reminderId: String, isDone: Bool) {
        db.collection("reminders").document(reminderId).updateData([
            "isDone": isDone
        ]) { error in
            DispatchQueue.main.async {
                if let error = error {
                    #if DEBUG
                    print("ReminderViewModel: Error toggling reminder: \(error.localizedDescription)")
                    #endif
                } else {
                    #if DEBUG
                    print("ReminderViewModel: Reminder toggled successfully")
                    #endif
                }
            }
        }
    }

    /// Delete a reminder - syncs deletion across all linked shared reminders
    func deleteReminder(_ reminder: Reminder) {
        #if DEBUG
        print("ReminderViewModel: Deleting reminder '\(reminder.title)'")
        #endif

        // If this reminder has a sharedReminderId, delete all linked reminders
        if let sharedReminderId = reminder.sharedReminderId {
            #if DEBUG
            print("ReminderViewModel: Syncing deletion across shared reminders with sharedReminderId: \(sharedReminderId)")
            #endif

            db.collection("reminders")
                .whereField("sharedReminderId", isEqualTo: sharedReminderId)
                .getDocuments { [weak self] snapshot, error in
                    guard let self = self else { return }

                    if let error = error {
                        #if DEBUG
                        print("ReminderViewModel: Error finding linked reminders: \(error.localizedDescription)")
                        #endif
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

                    batch.commit { [weak self] error in
                        DispatchQueue.main.async {
                            if let error = error {
                                #if DEBUG
                                print("ReminderViewModel: Error syncing deletion: \(error.localizedDescription)")
                                #endif
                                self?.errorMessage = "Failed to delete shared reminders: \(error.localizedDescription)"
                            } else {
                                #if DEBUG
                                print("ReminderViewModel: Synced deletion across \(documents.count) linked reminders")
                                #endif
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
        db.collection("reminders").document(reminderId).delete { [weak self] error in
            DispatchQueue.main.async {
                if let error = error {
                    #if DEBUG
                    print("ReminderViewModel: Error deleting reminder: \(error.localizedDescription)")
                    #endif
                    self?.errorMessage = "Failed to delete reminder: \(error.localizedDescription)"
                } else {
                    #if DEBUG
                    print("ReminderViewModel: Reminder deleted successfully")
                    #endif
                }
            }
        }
    }

    /// Delete a photo from a reminder by removing it from Storage and Firestore
    func deletePhoto(for reminder: Reminder, photoURL: String) {
        // Remove from Firebase Storage
        let storageRef = Storage.storage().reference(forURL: photoURL)
        storageRef.delete { [weak self] error in
            if let error = error {
                #if DEBUG
                print("ReminderViewModel: Error deleting photo from storage: \(error.localizedDescription)")
                #endif
                DispatchQueue.main.async {
                    self?.errorMessage = "Failed to delete photo: \(error.localizedDescription)"
                }
            } else {
                #if DEBUG
                print("ReminderViewModel: Photo deleted from storage")
                #endif
            }
        }

        // Remove URL from the Firestore array
        var currentURLs = reminder.photoURLs ?? []
        currentURLs.removeAll { $0 == photoURL }

        db.collection("reminders").document(reminder.id).updateData([
            "photoURLs": currentURLs
        ]) { [weak self] error in
            if let error = error {
                #if DEBUG
                print("ReminderViewModel: Error updating photoURLs: \(error.localizedDescription)")
                #endif
                DispatchQueue.main.async {
                    self?.errorMessage = "Failed to remove photo from reminder: \(error.localizedDescription)"
                }
            } else {
                #if DEBUG
                print("ReminderViewModel: Photo URL removed from reminder")
                #endif
            }
        }
    }

    /// Upload a photo for a reminder and append its URL to the reminder's photoURLs array
    func uploadPhoto(for reminder: Reminder, image: UIImage) {
        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            #if DEBUG
            print("ReminderViewModel: Failed to convert image to JPEG data")
            #endif
            DispatchQueue.main.async {
                self.errorMessage = "Failed to process image for upload"
            }
            return
        }

        let photoId = UUID().uuidString
        let storageRef = Storage.storage().reference()
        let photoRef = storageRef.child("reminder_photos/\(reminder.id)/\(photoId).jpg")

        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        photoRef.putData(imageData, metadata: metadata) { [weak self] _, error in
            guard let self = self else { return }

            if let error = error {
                #if DEBUG
                print("ReminderViewModel: Error uploading photo: \(error.localizedDescription)")
                #endif
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to upload photo: \(error.localizedDescription)"
                }
                return
            }

            photoRef.downloadURL { [weak self] url, error in
                if let error = error {
                    #if DEBUG
                    print("ReminderViewModel: Error getting download URL: \(error.localizedDescription)")
                    #endif
                    DispatchQueue.main.async {
                        self?.errorMessage = "Failed to upload photo: \(error.localizedDescription)"
                    }
                    return
                }

                guard let downloadURL = url?.absoluteString else { return }

                // Append the new photo URL to the existing array
                var currentURLs = reminder.photoURLs ?? []
                currentURLs.append(downloadURL)

                self?.db.collection("reminders").document(reminder.id).updateData([
                    "photoURLs": currentURLs
                ]) { error in
                    if let error = error {
                        #if DEBUG
                        print("ReminderViewModel: Error saving photo URL: \(error.localizedDescription)")
                        #endif
                        DispatchQueue.main.async {
                            self?.errorMessage = "Failed to save photo: \(error.localizedDescription)"
                        }
                    } else {
                        #if DEBUG
                        print("ReminderViewModel: Photo uploaded and URL saved successfully")
                        #endif
                    }
                }
            }
        }
    }
}
