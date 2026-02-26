//
//  SharedReminderNotificationService.swift
//  Geolocation_v1.0.0
//
//  Sends notifications to shared store users when reminders are changed,
//  and listens for incoming notifications from other users.
//

import Foundation
import FirebaseFirestore

class SharedReminderNotificationService {
    static let shared = SharedReminderNotificationService()

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    private init() {}

    // MARK: - Send Notifications

    /// Send reminder change notifications to all users sharing the same store.
    /// Called when the editing user navigates away from ReminderView.
    func sendNotifications(
        for userStoreItem: UserStoreItem,
        addedCount: Int,
        otherChangeCount: Int,
        currentUserId: String,
        currentUserName: String
    ) {
        let storeName = userStoreItem.store.name

        #if DEBUG
        print("SharedReminderNotificationService: Preparing notifications for '\(storeName)' (added: \(addedCount), other: \(otherChangeCount))")
        #endif

        findSharedUserIds(for: userStoreItem, excludingUserId: currentUserId) { [weak self] userIds in
            guard let self = self, !userIds.isEmpty else {
                #if DEBUG
                print("SharedReminderNotificationService: No shared users found to notify")
                #endif
                return
            }

            #if DEBUG
            print("SharedReminderNotificationService: Notifying \(userIds.count) shared user(s)")
            #endif

            let batch = self.db.batch()
            let now = Date().timeIntervalSince1970

            for userId in userIds {
                let docRef = self.db.collection("reminder_change_notifications").document()
                batch.setData([
                    "recipientUserId": userId,
                    "senderName": currentUserName,
                    "storeName": storeName,
                    "addedCount": addedCount,
                    "otherChangeCount": otherChangeCount,
                    "createdAt": now
                ], forDocument: docRef)
            }

            batch.commit { error in
                #if DEBUG
                if let error = error {
                    print("SharedReminderNotificationService: Error sending notifications: \(error.localizedDescription)")
                } else {
                    print("SharedReminderNotificationService: Notifications sent to \(userIds.count) user(s)")
                }
                #endif
            }
        }
    }

    // MARK: - Find Shared Users

    /// Find all user IDs that share the same store, excluding the current user.
    /// Respects each recipient's `notificationsEnabled` preference.
    private func findSharedUserIds(
        for userStoreItem: UserStoreItem,
        excludingUserId currentUserId: String,
        completion: @escaping ([String]) -> Void
    ) {
        var userIds = Set<String>()
        let group = DispatchGroup()

        // Case 1: Current user is the owner — find view-only recipients
        if userStoreItem.permission == .owner {
            group.enter()
            db.collection("user_stores")
                .whereField("sourceUserStoreId", isEqualTo: userStoreItem.id)
                .getDocuments { snapshot, _ in
                    if let docs = snapshot?.documents {
                        for doc in docs {
                            let data = doc.data()
                            if let userId = data["userId"] as? String,
                               userId != currentUserId,
                               data["notificationsEnabled"] as? Bool ?? true {
                                userIds.insert(userId)
                            }
                        }
                    }
                    group.leave()
                }
        }

        // Case 2: Store belongs to a shared edit group — find all co-editors
        if let groupId = userStoreItem.sharedStoreGroupId {
            group.enter()
            db.collection("user_stores")
                .whereField("sharedStoreGroupId", isEqualTo: groupId)
                .getDocuments { snapshot, _ in
                    if let docs = snapshot?.documents {
                        for doc in docs {
                            let data = doc.data()
                            if let userId = data["userId"] as? String,
                               userId != currentUserId,
                               data["notificationsEnabled"] as? Bool ?? true {
                                userIds.insert(userId)
                            }
                        }
                    }
                    group.leave()
                }
        }

        // Case 3: Current user is a view-only recipient — find the owner and other recipients
        if let sourceId = userStoreItem.sourceUserStoreId {
            group.enter()
            // Find the owner
            db.collection("user_stores").document(sourceId).getDocument { [weak self] snapshot, _ in
                if let data = snapshot?.data(),
                   let userId = data["userId"] as? String,
                   userId != currentUserId,
                   data["notificationsEnabled"] as? Bool ?? true {
                    userIds.insert(userId)
                }

                // Find other recipients that share the same source
                self?.db.collection("user_stores")
                    .whereField("sourceUserStoreId", isEqualTo: sourceId)
                    .getDocuments { snapshot, _ in
                        if let docs = snapshot?.documents {
                            for doc in docs {
                                let data = doc.data()
                                if let userId = data["userId"] as? String,
                                   userId != currentUserId,
                                   data["notificationsEnabled"] as? Bool ?? true {
                                    userIds.insert(userId)
                                }
                            }
                        }
                        group.leave()
                    }
            }
        }

        group.notify(queue: .main) {
            completion(Array(userIds))
        }
    }

    // MARK: - Listen for Incoming Notifications

    /// Start listening for shared reminder notifications addressed to the current user.
    /// Shows a local notification for each incoming document and then deletes it.
    func startListening(userId: String) {
        listener?.remove()

        #if DEBUG
        print("SharedReminderNotificationService: Starting listener for userId: \(userId)")
        #endif

        listener = db.collection("reminder_change_notifications")
            .whereField("recipientUserId", isEqualTo: userId)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    #if DEBUG
                    print("SharedReminderNotificationService: Listener error: \(error.localizedDescription)")
                    #endif
                    return
                }

                guard let snapshot = snapshot else { return }

                // Only process newly added documents (avoids re-processing on reconnect)
                let newDocs = snapshot.documentChanges.filter { $0.type == .added }

                for change in newDocs {
                    let data = change.document.data()
                    let senderName = data["senderName"] as? String ?? "Someone"
                    let storeName = data["storeName"] as? String ?? "a store"
                    let addedCount = data["addedCount"] as? Int ?? 0
                    let otherChangeCount = data["otherChangeCount"] as? Int ?? 0

                    #if DEBUG
                    print("SharedReminderNotificationService: Received notification - \(senderName) changed '\(storeName)'")
                    #endif

                    // Schedule a local notification on this device
                    NotificationManager.shared.scheduleSharedReminderNotification(
                        senderName: senderName,
                        storeName: storeName,
                        addedCount: addedCount,
                        otherChangeCount: otherChangeCount
                    )

                    // Delete the document after processing
                    change.document.reference.delete { error in
                        #if DEBUG
                        if let error = error {
                            print("SharedReminderNotificationService: Error deleting notification doc: \(error.localizedDescription)")
                        }
                        #endif
                    }
                }
            }
    }

    /// Stop listening for incoming notifications.
    func stopListening() {
        listener?.remove()
        listener = nil
    }

    deinit {
        listener?.remove()
    }
}
