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
        print("📤 SharedReminderNotificationService: --- SEND START ---")
        print("📤   Store: '\(storeName)', permission: \(userStoreItem.permission)")
        print("📤   isShared: \(userStoreItem.isShared), added: \(addedCount), other: \(otherChangeCount)")
        print("📤   currentUserId: \(currentUserId), currentUserName: \(currentUserName)")
        print("📤   userStoreItem.id: \(userStoreItem.id)")
        print("📤   sourceUserStoreId: \(userStoreItem.sourceUserStoreId ?? "nil")")
        print("📤   sharedStoreGroupId: \(userStoreItem.sharedStoreGroupId ?? "nil")")
        print("📤   sharedWith: \(userStoreItem.sharedWith ?? [])")
        print("📤   sharedFromName: \(userStoreItem.sharedFromName ?? "nil")")
        #endif

        findSharedUserIds(for: userStoreItem, excludingUserId: currentUserId) { [weak self] userIds in
            guard let self = self else {
                #if DEBUG
                print("📤 SharedReminderNotificationService: self is nil in findSharedUserIds completion")
                #endif
                return
            }

            guard !userIds.isEmpty else {
                #if DEBUG
                print("📤 SharedReminderNotificationService: No shared users found to notify")
                #endif
                return
            }

            #if DEBUG
            print("📤 SharedReminderNotificationService: Found \(userIds.count) user(s) to notify: \(userIds)")
            #endif

            let batch = self.db.batch()
            let now = Date().timeIntervalSince1970

            for userId in userIds {
                let docRef = self.db.collection("reminder_change_notifications").document()
                #if DEBUG
                print("📤   Writing notification doc \(docRef.documentID) for userId: \(userId)")
                #endif
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
                    print("📤 SharedReminderNotificationService: ❌ Batch commit error: \(error.localizedDescription)")
                } else {
                    print("📤 SharedReminderNotificationService: ✅ Notifications sent to \(userIds.count) user(s)")
                }
                print("📤 SharedReminderNotificationService: --- SEND END ---")
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

        #if DEBUG
        print("📤 findSharedUserIds: permission=\(userStoreItem.permission), id=\(userStoreItem.id), sourceUserStoreId=\(userStoreItem.sourceUserStoreId ?? "nil"), sharedStoreGroupId=\(userStoreItem.sharedStoreGroupId ?? "nil")")
        #endif

        // Case 1: Current user is the owner — find all recipients (both edit and view)
        if userStoreItem.permission == .owner {
            group.enter()
            #if DEBUG
            print("📤 findSharedUserIds: Case 1 (owner) — querying sourceUserStoreId == \(userStoreItem.id)")
            #endif
            db.collection("user_stores")
                .whereField("sourceUserStoreId", isEqualTo: userStoreItem.id)
                .getDocuments { snapshot, error in
                    #if DEBUG
                    if let error = error {
                        print("📤 findSharedUserIds: Case 1 error: \(error.localizedDescription)")
                    }
                    print("📤 findSharedUserIds: Case 1 found \(snapshot?.documents.count ?? 0) document(s)")
                    #endif
                    if let docs = snapshot?.documents {
                        for doc in docs {
                            let data = doc.data()
                            let userId = data["userId"] as? String
                            let notifEnabled = data["notificationsEnabled"] as? Bool ?? true
                            #if DEBUG
                            print("📤   Case 1 doc \(doc.documentID): userId=\(userId ?? "nil"), notifEnabled=\(notifEnabled)")
                            #endif
                            if let userId = userId,
                               userId != currentUserId,
                               notifEnabled {
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
            #if DEBUG
            print("📤 findSharedUserIds: Case 2 (shared group) — querying sharedStoreGroupId == \(groupId)")
            #endif
            db.collection("user_stores")
                .whereField("sharedStoreGroupId", isEqualTo: groupId)
                .getDocuments { snapshot, error in
                    #if DEBUG
                    if let error = error {
                        print("📤 findSharedUserIds: Case 2 error: \(error.localizedDescription)")
                    }
                    print("📤 findSharedUserIds: Case 2 found \(snapshot?.documents.count ?? 0) document(s)")
                    #endif
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

        // Case 3: Current user is a recipient — find the owner and other recipients
        if let sourceId = userStoreItem.sourceUserStoreId {
            group.enter()
            #if DEBUG
            print("📤 findSharedUserIds: Case 3 (recipient) — looking up owner doc \(sourceId) and querying sourceUserStoreId == \(sourceId)")
            #endif
            // Find the owner
            db.collection("user_stores").document(sourceId).getDocument { [weak self] snapshot, error in
                #if DEBUG
                if let error = error {
                    print("📤 findSharedUserIds: Case 3 owner lookup error: \(error.localizedDescription)")
                }
                #endif
                if let data = snapshot?.data(),
                   let userId = data["userId"] as? String,
                   userId != currentUserId,
                   data["notificationsEnabled"] as? Bool ?? true {
                    #if DEBUG
                    print("📤 findSharedUserIds: Case 3 found owner userId: \(userId)")
                    #endif
                    userIds.insert(userId)
                } else {
                    #if DEBUG
                    print("📤 findSharedUserIds: Case 3 owner doc data: \(snapshot?.data() ?? [:])")
                    #endif
                }

                // Find other recipients that share the same source
                guard let self = self else {
                    #if DEBUG
                    print("📤 findSharedUserIds: Case 3 self is nil, calling group.leave()")
                    #endif
                    group.leave()
                    return
                }

                self.db.collection("user_stores")
                    .whereField("sourceUserStoreId", isEqualTo: sourceId)
                    .getDocuments { snapshot, error in
                        #if DEBUG
                        if let error = error {
                            print("📤 findSharedUserIds: Case 3 other recipients error: \(error.localizedDescription)")
                        }
                        print("📤 findSharedUserIds: Case 3 found \(snapshot?.documents.count ?? 0) other recipient(s)")
                        #endif
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

        #if DEBUG
        let casesEntered = (userStoreItem.permission == .owner ? 1 : 0)
            + (userStoreItem.sharedStoreGroupId != nil ? 1 : 0)
            + (userStoreItem.sourceUserStoreId != nil ? 1 : 0)
        print("📤 findSharedUserIds: \(casesEntered) case(s) entered, waiting for completion...")
        if casesEntered == 0 {
            print("📤 findSharedUserIds: ⚠️ NO cases matched! permission=\(userStoreItem.permission), sourceUserStoreId=\(userStoreItem.sourceUserStoreId ?? "nil")")
        }
        #endif

        group.notify(queue: .main) {
            #if DEBUG
            print("📤 findSharedUserIds: completed with \(userIds.count) user(s): \(userIds)")
            #endif
            completion(Array(userIds))
        }
    }

    // MARK: - Listen for Incoming Notifications

    /// Start listening for shared reminder notifications addressed to the current user.
    /// Shows a local notification for each incoming document and then deletes it.
    func startListening(userId: String) {
        listener?.remove()

        #if DEBUG
        print("📥 SharedReminderNotificationService: Starting listener for userId: \(userId)")
        #endif

        listener = db.collection("reminder_change_notifications")
            .whereField("recipientUserId", isEqualTo: userId)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    #if DEBUG
                    print("📥 SharedReminderNotificationService: ❌ Listener error: \(error.localizedDescription)")
                    #endif
                    return
                }

                guard let snapshot = snapshot else {
                    #if DEBUG
                    print("📥 SharedReminderNotificationService: snapshot is nil")
                    #endif
                    return
                }

                // Only process newly added documents (avoids re-processing on reconnect)
                let newDocs = snapshot.documentChanges.filter { $0.type == .added }

                #if DEBUG
                if !newDocs.isEmpty {
                    print("📥 SharedReminderNotificationService: Received \(newDocs.count) new notification(s)")
                }
                #endif

                for change in newDocs {
                    let data = change.document.data()
                    let senderName = data["senderName"] as? String ?? "Someone"
                    let storeName = data["storeName"] as? String ?? "a store"
                    let addedCount = data["addedCount"] as? Int ?? 0
                    let otherChangeCount = data["otherChangeCount"] as? Int ?? 0

                    #if DEBUG
                    print("📥   Notification: \(senderName) changed '\(storeName)' (added: \(addedCount), other: \(otherChangeCount))")
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
                            print("📥 SharedReminderNotificationService: Error deleting notification doc: \(error.localizedDescription)")
                        } else {
                            print("📥 SharedReminderNotificationService: Deleted processed notification doc")
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
