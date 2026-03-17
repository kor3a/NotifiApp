//
//  OnMyWayNotificationService.swift
//  Geolocation_v1.0.0
//
//  Sends "on my way" notifications to shared store users via Firestore
//  and listens for incoming notifications from other users.
//

import Foundation
import FirebaseFirestore

class OnMyWayNotificationService {
    static let shared = OnMyWayNotificationService()

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    /// Unix timestamp recorded when startListening() is called.
    /// Filters to docs created AFTER this time so the client does not
    /// re-process notifications already delivered by FCM while app was closed.
    private var listenerStartTime: Double = 0

    private init() {}

    // MARK: - Send Notifications

    /// Send "on my way" notifications to all users sharing the same store.
    func sendNotification(
        for userStoreItem: UserStoreItem,
        travelTimeMinutes: Int,
        currentUserId: String,
        currentUserName: String
    ) {
        let storeName = userStoreItem.store.name

        #if DEBUG
        print("🚗 OnMyWayNotificationService: --- SEND START ---")
        print("🚗   Store: '\(storeName)', travelTime: \(travelTimeMinutes) min")
        print("🚗   currentUserId: \(currentUserId), currentUserName: \(currentUserName)")
        #endif

        findSharedUsers(for: userStoreItem, excludingUserId: currentUserId) { [weak self] sharedUsers in
            guard let self = self else { return }

            guard !sharedUsers.isEmpty else {
                #if DEBUG
                print("🚗 OnMyWayNotificationService: No shared users found to notify")
                #endif
                return
            }

            #if DEBUG
            print("🚗 OnMyWayNotificationService: Found \(sharedUsers.count) user(s) to notify")
            #endif

            let batch = self.db.batch()
            let now = Date().timeIntervalSince1970

            for user in sharedUsers {
                let docRef = self.db.collection("on_my_way_notifications").document()
                batch.setData([
                    "recipientUserId": user.userId,
                    "recipientEmail": user.email,
                    "senderName": currentUserName,
                    "storeName": storeName,
                    "travelTimeMinutes": travelTimeMinutes,
                    "createdAt": now
                ], forDocument: docRef)
            }

            batch.commit { error in
                #if DEBUG
                if let error = error {
                    print("🚗 OnMyWayNotificationService: ❌ Batch commit error: \(error.localizedDescription)")
                } else {
                    print("🚗 OnMyWayNotificationService: ✅ Notifications sent to \(sharedUsers.count) user(s)")
                }
                print("🚗 OnMyWayNotificationService: --- SEND END ---")
                #endif
            }
        }
    }

    // MARK: - Find Shared Users

    private struct SharedUser {
        let userId: String
        let email: String
    }

    /// Find all users that share the same store, excluding the current user.
    private func findSharedUsers(
        for userStoreItem: UserStoreItem,
        excludingUserId currentUserId: String,
        completion: @escaping ([SharedUser]) -> Void
    ) {
        var usersById = [String: SharedUser]()
        let group = DispatchGroup()

        // Case 1: Current user is the owner — find all recipients
        if userStoreItem.permission == .owner {
            group.enter()
            db.collection("user_stores")
                .whereField("sourceUserStoreId", isEqualTo: userStoreItem.id)
                .getDocuments { snapshot, _ in
                    if let docs = snapshot?.documents {
                        for doc in docs {
                            let data = doc.data()
                            if let userId = data["userId"] as? String,
                               let email = data["userEmail"] as? String,
                               userId != currentUserId {
                                usersById[userId] = SharedUser(userId: userId, email: email)
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
                               let email = data["userEmail"] as? String,
                               userId != currentUserId {
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
            db.collection("user_stores").document(sourceId).getDocument { [weak self] snapshot, _ in
                if let data = snapshot?.data(),
                   let userId = data["userId"] as? String,
                   let email = data["userEmail"] as? String,
                   userId != currentUserId {
                    usersById[userId] = SharedUser(userId: userId, email: email)
                }

                guard let self = self else {
                    group.leave()
                    return
                }

                self.db.collection("user_stores")
                    .whereField("sourceUserStoreId", isEqualTo: sourceId)
                    .getDocuments { snapshot, _ in
                        if let docs = snapshot?.documents {
                            for doc in docs {
                                let data = doc.data()
                                if let userId = data["userId"] as? String,
                                   let email = data["userEmail"] as? String,
                                   userId != currentUserId {
                                    usersById[userId] = SharedUser(userId: userId, email: email)
                                }
                            }
                        }
                        group.leave()
                    }
            }
        }

        group.notify(queue: .main) {
            completion(Array(usersById.values))
        }
    }

    // MARK: - Listen for Incoming Notifications

    /// Start listening for "on my way" notifications addressed to the current user.
    func startListening(userEmail: String) {
        listener?.remove()
        listenerStartTime = Date().timeIntervalSince1970

        #if DEBUG
        print("🚗 OnMyWayNotificationService: Starting listener for email: \(userEmail), startTime: \(listenerStartTime)")
        #endif

        listener = db.collection("on_my_way_notifications")
            .whereField("recipientEmail", isEqualTo: userEmail)
            .whereField("createdAt", isGreaterThan: listenerStartTime)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    #if DEBUG
                    print("🚗 OnMyWayNotificationService: ❌ Listener error: \(error.localizedDescription)")
                    #endif
                    return
                }

                guard let snapshot = snapshot else { return }

                let newDocs = snapshot.documentChanges.filter { $0.type == .added }

                for change in newDocs {
                    let data = change.document.data()
                    let senderName = data["senderName"] as? String ?? "Someone"
                    let storeName = data["storeName"] as? String ?? "a store"
                    let travelTimeMinutes = data["travelTimeMinutes"] as? Int ?? 0

                    #if DEBUG
                    print("🚗 OnMyWayNotificationService: Received notification - \(senderName) is on their way to \(storeName) (\(travelTimeMinutes) min)")
                    #endif

                    NotificationManager.shared.scheduleOnMyWayNotification(
                        senderName: senderName,
                        storeName: storeName,
                        travelTimeMinutes: travelTimeMinutes
                    )

                    // Delete the document after processing
                    change.document.reference.delete()
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
