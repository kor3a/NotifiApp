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
    private var activeEmail: String?
    /// Tracks Firestore document IDs already processed this session.
    /// Prevents duplicate notifications when startListening() is called twice quickly.
    private var processedDocIds: Set<String> = []

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

        findSharedUsers(for: userStoreItem, excludingUserId: currentUserId) { [weak self] sharedUsers in
            guard let self = self else {
                #if DEBUG
                print("📤 SharedReminderNotificationService: self is nil in completion")
                #endif
                return
            }

            guard !sharedUsers.isEmpty else {
                #if DEBUG
                print("📤 SharedReminderNotificationService: No shared users found to notify")
                #endif
                return
            }

            #if DEBUG
            print("📤 SharedReminderNotificationService: Found \(sharedUsers.count) user(s) to notify: \(sharedUsers.map { $0.email })")
            #endif

            let batch = self.db.batch()
            let now = Date().timeIntervalSince1970

            for user in sharedUsers {
                let docRef = self.db.collection("reminder_change_notifications").document()
                #if DEBUG
                print("📤   Writing notification doc \(docRef.documentID) for \(user.email)")
                #endif
                batch.setData([
                    "recipientUserId": user.userId,
                    "recipientEmail": user.email,
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
                    print("📤 SharedReminderNotificationService: ✅ Notifications sent to \(sharedUsers.count) user(s)")
                }
                print("📤 SharedReminderNotificationService: --- SEND END ---")
                #endif
            }
        }
    }

    // MARK: - Find Shared Users

    /// A shared user's userId and email, collected from user_stores documents.
    private struct SharedUser {
        let userId: String
        let email: String
    }

    /// Find all users that share the same store, excluding the current user.
    /// Respects each recipient's `notificationsEnabled` preference.
    private func findSharedUsers(
        for userStoreItem: UserStoreItem,
        excludingUserId currentUserId: String,
        completion: @escaping ([SharedUser]) -> Void
    ) {
        // Use a dictionary keyed by userId to deduplicate
        var usersById = [String: SharedUser]()
        let group = DispatchGroup()

        #if DEBUG
        print("📤 findSharedUsers: permission=\(userStoreItem.permission), id=\(userStoreItem.id), sourceUserStoreId=\(userStoreItem.sourceUserStoreId ?? "nil"), sharedStoreGroupId=\(userStoreItem.sharedStoreGroupId ?? "nil")")
        #endif

        // Case 1: Current user is the owner — find all recipients (both edit and view)
        if userStoreItem.permission == .owner {
            group.enter()
            #if DEBUG
            print("📤 findSharedUsers: Case 1 (owner) — querying sourceUserStoreId == \(userStoreItem.id)")
            #endif
            db.collection("user_stores")
                .whereField("sourceUserStoreId", isEqualTo: userStoreItem.id)
                .getDocuments { snapshot, error in
                    #if DEBUG
                    if let error = error {
                        print("📤 findSharedUsers: Case 1 error: \(error.localizedDescription)")
                    }
                    print("📤 findSharedUsers: Case 1 found \(snapshot?.documents.count ?? 0) document(s)")
                    #endif
                    if let docs = snapshot?.documents {
                        for doc in docs {
                            let data = doc.data()
                            if let userId = data["userId"] as? String,
                               let email = data["userEmail"] as? String,
                               userId != currentUserId,
                               data["notificationsEnabled"] as? Bool ?? true {
                                usersById[userId] = SharedUser(userId: userId, email: email)
                                #if DEBUG
                                print("📤   Case 1: found user \(userId) (\(email))")
                                #endif
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
            print("📤 findSharedUsers: Case 2 (shared group) — querying sharedStoreGroupId == \(groupId)")
            #endif
            db.collection("user_stores")
                .whereField("sharedStoreGroupId", isEqualTo: groupId)
                .getDocuments { snapshot, error in
                    #if DEBUG
                    if let error = error {
                        print("📤 findSharedUsers: Case 2 error: \(error.localizedDescription)")
                    }
                    print("📤 findSharedUsers: Case 2 found \(snapshot?.documents.count ?? 0) document(s)")
                    #endif
                    if let docs = snapshot?.documents {
                        for doc in docs {
                            let data = doc.data()
                            if let userId = data["userId"] as? String,
                               let email = data["userEmail"] as? String,
                               userId != currentUserId,
                               data["notificationsEnabled"] as? Bool ?? true {
                                usersById[userId] = SharedUser(userId: userId, email: email)
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
            print("📤 findSharedUsers: Case 3 (recipient) — looking up owner doc \(sourceId) and querying sourceUserStoreId == \(sourceId)")
            #endif
            // Find the owner
            db.collection("user_stores").document(sourceId).getDocument { [weak self] snapshot, error in
                #if DEBUG
                if let error = error {
                    print("📤 findSharedUsers: Case 3 owner lookup error: \(error.localizedDescription)")
                }
                #endif
                if let data = snapshot?.data(),
                   let userId = data["userId"] as? String,
                   let email = data["userEmail"] as? String,
                   userId != currentUserId,
                   data["notificationsEnabled"] as? Bool ?? true {
                    usersById[userId] = SharedUser(userId: userId, email: email)
                    #if DEBUG
                    print("📤 findSharedUsers: Case 3 found owner \(userId) (\(email))")
                    #endif
                } else {
                    #if DEBUG
                    print("📤 findSharedUsers: Case 3 owner doc data: \(snapshot?.data() ?? [:])")
                    #endif
                }

                // Find other recipients that share the same source
                guard let self = self else {
                    #if DEBUG
                    print("📤 findSharedUsers: Case 3 self is nil, calling group.leave()")
                    #endif
                    group.leave()
                    return
                }

                self.db.collection("user_stores")
                    .whereField("sourceUserStoreId", isEqualTo: sourceId)
                    .getDocuments { snapshot, error in
                        #if DEBUG
                        if let error = error {
                            print("📤 findSharedUsers: Case 3 other recipients error: \(error.localizedDescription)")
                        }
                        print("📤 findSharedUsers: Case 3 found \(snapshot?.documents.count ?? 0) other recipient(s)")
                        #endif
                        if let docs = snapshot?.documents {
                            for doc in docs {
                                let data = doc.data()
                                if let userId = data["userId"] as? String,
                                   let email = data["userEmail"] as? String,
                                   userId != currentUserId,
                                   data["notificationsEnabled"] as? Bool ?? true {
                                    usersById[userId] = SharedUser(userId: userId, email: email)
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
        print("📤 findSharedUsers: \(casesEntered) case(s) entered, waiting for completion...")
        if casesEntered == 0 {
            print("📤 findSharedUsers: ⚠️ NO cases matched! permission=\(userStoreItem.permission), sourceUserStoreId=\(userStoreItem.sourceUserStoreId ?? "nil")")
        }
        #endif

        group.notify(queue: .main) {
            let result = Array(usersById.values)
            #if DEBUG
            print("📤 findSharedUsers: completed with \(result.count) user(s): \(result.map { "\($0.userId) (\($0.email))" })")
            #endif
            completion(result)
        }
    }

    // MARK: - Listen for Incoming Notifications

    /// Start listening for shared reminder notifications addressed to the current user.
    /// Uses email for matching since userId is the app username, not the Firebase Auth UID.
    func startListening(userEmail: String) {
        // Idempotency guard: skip if already listening for the same email.
        guard userEmail != activeEmail else {
            #if DEBUG
            print("📥 SharedReminderNotificationService: Already listening for \(userEmail), skipping restart")
            #endif
            return
        }

        activeEmail = userEmail
        listener?.remove()

        #if DEBUG
        print("📥 SharedReminderNotificationService: Starting listener for email: \(userEmail)")
        #endif

        listener = db.collection("reminder_change_notifications")
            .whereField("recipientEmail", isEqualTo: userEmail)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }

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
                    let docId = change.document.documentID

                    // Skip if already processed this session
                    guard !self.processedDocIds.contains(docId) else { continue }
                    self.processedDocIds.insert(docId)

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
                        otherChangeCount: otherChangeCount,
                        notificationId: docId
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
        activeEmail = nil
        processedDocIds.removeAll()
    }

    deinit {
        listener?.remove()
    }
}
