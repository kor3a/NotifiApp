//
//  FriendsService.swift
//  Geolocation_v1.0.0
//
//  Created by Claude Code
//

import Foundation
import FirebaseFirestore

class FriendsService: ObservableObject {
    static let shared = FriendsService()

    private let db = Firestore.firestore()

    private init() {}

    // MARK: - Fetch Friends

    /// Fetch all friendships for a user (accepted, pending sent, pending received)
    func fetchFriendships(
        for userId: String,
        completion: @escaping (Result<[Friendship], Error>) -> Void
    ) -> ListenerRegistration {
        #if DEBUG
        print("FriendsService: Setting up friendships listener for userId: \(userId)")
        #endif

        // Query for friendships where user is either requester or receiver
        // Using two queries and merging results
        let listener = db.collection("friends")
            .whereField("participantIds", arrayContains: userId)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    #if DEBUG
                    print("FriendsService: Error fetching friendships: \(error.localizedDescription)")
                    #endif
                    completion(.failure(error))
                    return
                }

                guard let documents = snapshot?.documents else {
                    #if DEBUG
                    print("FriendsService: No friendship documents found")
                    #endif
                    completion(.success([]))
                    return
                }

                #if DEBUG
                print("FriendsService: Received \(documents.count) friendship documents from Firestore")
                #endif

                let friendships = documents.compactMap { doc -> Friendship? in
                    return self.parseFriendship(from: doc)
                }

                #if DEBUG
                print("FriendsService: Parsed \(friendships.count) valid friendships")
                #endif
                completion(.success(friendships))
            }

        return listener
    }

    /// Fetch only accepted friends
    func fetchAcceptedFriends(
        for userId: String,
        completion: @escaping (Result<[Friendship], Error>) -> Void
    ) -> ListenerRegistration {
        return db.collection("friends")
            .whereField("participantIds", arrayContains: userId)
            .whereField("status", isEqualTo: FriendshipStatus.accepted.rawValue)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }

                guard let documents = snapshot?.documents else {
                    completion(.success([]))
                    return
                }

                let friendships = documents.compactMap { doc -> Friendship? in
                    return self.parseFriendship(from: doc)
                }

                completion(.success(friendships))
            }
    }

    /// Fetch pending friend requests received by user
    func fetchPendingRequests(
        for userId: String,
        completion: @escaping (Result<[Friendship], Error>) -> Void
    ) -> ListenerRegistration {
        return db.collection("friends")
            .whereField("receiverId", isEqualTo: userId)
            .whereField("status", isEqualTo: FriendshipStatus.pending.rawValue)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }

                guard let documents = snapshot?.documents else {
                    completion(.success([]))
                    return
                }

                let friendships = documents.compactMap { doc -> Friendship? in
                    return self.parseFriendship(from: doc)
                }

                completion(.success(friendships))
            }
    }

    // MARK: - Send Friend Request

    /// Send a friend request to another user
    func sendFriendRequest(
        from requester: User,
        to receiver: Contact,
        completion: @escaping (Result<Friendship, Error>) -> Void
    ) {
        // Check if friendship already exists
        checkExistingFriendship(userId1: requester.userId, userId2: receiver.id) { [weak self] existingFriendship in
            guard let self = self else { return }

            if let existing = existingFriendship {
                // Friendship already exists
                if existing.status == .rejected {
                    // If previously rejected, we could allow re-requesting
                    // For now, just return the existing one
                    completion(.success(existing))
                } else {
                    completion(.success(existing))
                }
                return
            }

            // Create new friendship
            let now = Date().timeIntervalSince1970
            let friendshipData: [String: Any] = [
                "requesterId": requester.userId,
                "requesterName": requester.name,
                "requesterEmail": requester.email,
                "requesterProfilePictureURL": requester.profilePictureURL ?? "",
                "receiverId": receiver.id,
                "receiverName": receiver.name,
                "receiverEmail": receiver.email,
                "receiverProfilePictureURL": receiver.profilePictureURL ?? "",
                "status": FriendshipStatus.pending.rawValue,
                "createdAt": now,
                "participantIds": [requester.userId, receiver.id]
            ]

            var ref: DocumentReference?
            ref = self.db.collection("friends").addDocument(data: friendshipData) { error in
                if let error = error {
                    completion(.failure(error))
                    return
                }

                guard let docId = ref?.documentID else {
                    completion(.failure(NSError(domain: "FriendsService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create friendship"])))
                    return
                }

                let friendship = Friendship(
                    id: docId,
                    requesterId: requester.userId,
                    requesterName: requester.name,
                    requesterEmail: requester.email,
                    requesterProfilePictureURL: requester.profilePictureURL,
                    receiverId: receiver.id,
                    receiverName: receiver.name,
                    receiverEmail: receiver.email,
                    receiverProfilePictureURL: receiver.profilePictureURL,
                    status: .pending,
                    createdAt: now,
                    acceptedAt: nil
                )

                completion(.success(friendship))
            }
        }
    }

    /// Check if a friendship already exists between two users
    private func checkExistingFriendship(
        userId1: String,
        userId2: String,
        completion: @escaping (Friendship?) -> Void
    ) {
        db.collection("friends")
            .whereField("participantIds", arrayContains: userId1)
            .getDocuments { snapshot, error in
                if let error = error {
                    #if DEBUG
                    print("FriendsService: Error checking existing friendship: \(error)")
                    #endif
                    completion(nil)
                    return
                }

                // Find friendship that contains both users
                let existingFriendship = snapshot?.documents.compactMap { doc -> Friendship? in
                    guard let participantIds = doc.data()["participantIds"] as? [String],
                          participantIds.contains(userId2) else {
                        return nil
                    }
                    return self.parseFriendship(from: doc)
                }.first

                completion(existingFriendship)
            }
    }

    // MARK: - Accept/Reject Friend Request

    /// Accept a friend request
    func acceptFriendRequest(
        friendshipId: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let now = Date().timeIntervalSince1970
        db.collection("friends").document(friendshipId).updateData([
            "status": FriendshipStatus.accepted.rawValue,
            "acceptedAt": now
        ]) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }

    /// Reject a friend request
    func rejectFriendRequest(
        friendshipId: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        db.collection("friends").document(friendshipId).updateData([
            "status": FriendshipStatus.rejected.rawValue
        ]) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }

    // MARK: - Remove Friend

    /// Remove a friendship (unfriend)
    func removeFriend(
        friendshipId: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        #if DEBUG
        print("FriendsService: Attempting to delete friendship with ID: \(friendshipId)")
        #endif

        db.collection("friends").document(friendshipId).delete { error in
            if let error = error {
                #if DEBUG
                print("FriendsService: ERROR deleting friendship \(friendshipId): \(error.localizedDescription)")
                #endif
                completion(.failure(error))
            } else {
                #if DEBUG
                print("FriendsService: Successfully deleted friendship \(friendshipId)")
                #endif
                completion(.success(()))
            }
        }
    }

    // MARK: - Unshare Stores on Unfriend

    /// When unfriending, remove all shared stores between the two users.
    /// This handles both directions: stores the current user shared with the friend,
    /// and stores the friend shared with the current user.
    func unshareAllStoresBetweenUsers(
        currentUserId: String,
        currentUserName: String,
        friendId: String,
        friendName: String,
        completion: @escaping (Result<Int, Error>) -> Void
    ) {
        let group = DispatchGroup()
        var totalUnshared = 0
        var firstError: Error?

        // Direction 1: Stores the current user owns that are shared with the friend
        // Find friend's user_stores where sharedFrom == currentUserId
        group.enter()
        db.collection("user_stores")
            .whereField("userId", isEqualTo: friendId)
            .whereField("sharedFrom", isEqualTo: currentUserId)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else {
                    group.leave()
                    return
                }

                if let error = error {
                    #if DEBUG
                    print("FriendsService: Error finding stores shared with friend: \(error.localizedDescription)")
                    #endif
                    if firstError == nil { firstError = error }
                    group.leave()
                    return
                }

                guard let documents = snapshot?.documents, !documents.isEmpty else {
                    #if DEBUG
                    print("FriendsService: No stores found that current user shared with friend")
                    #endif
                    group.leave()
                    return
                }

                #if DEBUG
                print("FriendsService: Found \(documents.count) store(s) shared with friend '\(friendName)' - removing")
                #endif

                let innerGroup = DispatchGroup()

                for doc in documents {
                    let data = doc.data()
                    let recipientUserStoreId = doc.documentID
                    let sourceUserStoreId = data["sourceUserStoreId"] as? String
                    let permission = data["permission"] as? String ?? ""

                    innerGroup.enter()

                    if permission == "owner" {
                        // Merged store: the friend owns this store — just clear sharing fields
                        // rather than deleting their store entirely.
                        self.db.collection("user_stores").document(recipientUserStoreId).updateData([
                            "sourceUserStoreId": FieldValue.delete(),
                            "sharedFrom":        FieldValue.delete(),
                            "sharedFromName":    FieldValue.delete(),
                            "sharedWith":        FieldValue.delete()
                        ]) { error in
                            if error == nil { totalUnshared += 1 }
                            // Clean up reminder items that crossed the merge boundary
                            self.cleanUpMergedStoreRemindersOnUnshare(
                                mergedStoreId: recipientUserStoreId,
                                ownerUserId: currentUserId,
                                ownerName: currentUserName
                            )
                            // Update the owner's (current user's) user_store and reminders
                            if let ownerStoreId = sourceUserStoreId {
                                self.cleanUpOwnerAfterUnshare(
                                    ownerUserStoreId: ownerStoreId,
                                    recipientName: friendName
                                )
                            }
                            innerGroup.leave()
                        }
                    } else {
                        // Regular shared store: delete the friend's user_store document
                        self.db.collection("user_stores").document(recipientUserStoreId).delete { error in
                            if let error = error {
                                #if DEBUG
                                print("FriendsService: Error deleting friend's user_store \(recipientUserStoreId): \(error.localizedDescription)")
                                #endif
                                if firstError == nil { firstError = error }
                            } else {
                                totalUnshared += 1
                                #if DEBUG
                                print("FriendsService: Deleted friend's user_store \(recipientUserStoreId)")
                                #endif
                            }

                            // Update the owner's (current user's) user_store and reminders
                            if let ownerStoreId = sourceUserStoreId {
                                self.cleanUpOwnerAfterUnshare(
                                    ownerUserStoreId: ownerStoreId,
                                    recipientName: friendName
                                )
                            }

                            innerGroup.leave()
                        }
                    }
                }

                innerGroup.notify(queue: .main) {
                    group.leave()
                }
            }

        // Direction 2: Stores the friend owns that are shared with the current user
        // Find current user's user_stores where sharedFrom == friendId
        group.enter()
        db.collection("user_stores")
            .whereField("userId", isEqualTo: currentUserId)
            .whereField("sharedFrom", isEqualTo: friendId)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else {
                    group.leave()
                    return
                }

                if let error = error {
                    #if DEBUG
                    print("FriendsService: Error finding stores shared by friend: \(error.localizedDescription)")
                    #endif
                    if firstError == nil { firstError = error }
                    group.leave()
                    return
                }

                guard let documents = snapshot?.documents, !documents.isEmpty else {
                    #if DEBUG
                    print("FriendsService: No stores found that friend shared with current user")
                    #endif
                    group.leave()
                    return
                }

                #if DEBUG
                print("FriendsService: Found \(documents.count) store(s) shared by friend '\(friendName)' - removing")
                #endif

                let innerGroup = DispatchGroup()

                for doc in documents {
                    let data = doc.data()
                    let recipientUserStoreId = doc.documentID
                    let sourceUserStoreId = data["sourceUserStoreId"] as? String
                    let permission = data["permission"] as? String ?? ""

                    innerGroup.enter()

                    if permission == "owner" {
                        // Merged store: the current user owns this store — just clear sharing fields.
                        self.db.collection("user_stores").document(recipientUserStoreId).updateData([
                            "sourceUserStoreId": FieldValue.delete(),
                            "sharedFrom":        FieldValue.delete(),
                            "sharedFromName":    FieldValue.delete(),
                            "sharedWith":        FieldValue.delete()
                        ]) { error in
                            if error == nil { totalUnshared += 1 }
                            // Clean up reminder items that crossed the merge boundary
                            self.cleanUpMergedStoreRemindersOnUnshare(
                                mergedStoreId: recipientUserStoreId,
                                ownerUserId: friendId,
                                ownerName: friendName
                            )
                            // Update the owner's (friend's) user_store and reminders
                            if let ownerStoreId = sourceUserStoreId {
                                self.cleanUpOwnerAfterUnshare(
                                    ownerUserStoreId: ownerStoreId,
                                    recipientName: currentUserName
                                )
                            }
                            innerGroup.leave()
                        }
                    } else {
                        // Regular shared store: delete the current user's shared user_store document
                        self.db.collection("user_stores").document(recipientUserStoreId).delete { error in
                            if let error = error {
                                #if DEBUG
                                print("FriendsService: Error deleting current user's shared user_store \(recipientUserStoreId): \(error.localizedDescription)")
                                #endif
                                if firstError == nil { firstError = error }
                            } else {
                                totalUnshared += 1
                                #if DEBUG
                                print("FriendsService: Deleted current user's shared user_store \(recipientUserStoreId)")
                                #endif
                            }

                            // Update the owner's (friend's) user_store and reminders
                            if let ownerStoreId = sourceUserStoreId {
                                self.cleanUpOwnerAfterUnshare(
                                    ownerUserStoreId: ownerStoreId,
                                    recipientName: currentUserName
                                )
                            }

                            innerGroup.leave()
                        }
                    }
                }

                innerGroup.notify(queue: .main) {
                    group.leave()
                }
            }

        // When both directions are done, report results
        group.notify(queue: .main) {
            if let error = firstError, totalUnshared == 0 {
                completion(.failure(error))
            } else {
                #if DEBUG
                print("FriendsService: Unshared \(totalUnshared) store(s) between users")
                #endif
                completion(.success(totalUnshared))
            }
        }
    }

    /// Clean up the owner's user_store and reminders after a recipient is removed
    private func cleanUpOwnerAfterUnshare(ownerUserStoreId: String, recipientName: String) {
        // Update owner's user_store sharedWith
        let ownerDocRef = db.collection("user_stores").document(ownerUserStoreId)
        ownerDocRef.getDocument { [weak self] snapshot, error in
            guard let self = self else { return }

            if let error = error {
                #if DEBUG
                print("FriendsService: Error fetching owner's user_store: \(error.localizedDescription)")
                #endif
                return
            }

            guard let data = snapshot?.data() else {
                #if DEBUG
                print("FriendsService: Owner's user_store \(ownerUserStoreId) not found")
                #endif
                return
            }

            var sharedWith = data["sharedWith"] as? [String] ?? []
            sharedWith.removeAll { $0 == recipientName }

            if sharedWith.isEmpty {
                // No more shared users, clear sharing fields
                ownerDocRef.updateData([
                    "sharedWith": FieldValue.delete(),
                    "isSharedStore": FieldValue.delete()
                ]) { error in
                    #if DEBUG
                    if let error = error {
                        print("FriendsService: Error clearing owner's sharedWith: \(error.localizedDescription)")
                    } else {
                        print("FriendsService: Cleared owner's sharedWith for \(ownerUserStoreId)")
                    }
                    #endif
                }
            } else {
                ownerDocRef.updateData([
                    "sharedWith": sharedWith
                ]) { error in
                    #if DEBUG
                    if let error = error {
                        print("FriendsService: Error updating owner's sharedWith: \(error.localizedDescription)")
                    } else {
                        print("FriendsService: Updated owner's sharedWith to \(sharedWith)")
                    }
                    #endif
                }
            }

            // Update reminders to remove shared status with this recipient
            self.cleanUpRemindersAfterUnshare(
                ownerUserStoreId: ownerUserStoreId,
                recipientName: recipientName
            )
        }
    }

    /// Clean up shared reminders after a recipient is removed
    private func cleanUpRemindersAfterUnshare(ownerUserStoreId: String, recipientName: String) {
        db.collection("reminders")
            .whereField("userStoreId", isEqualTo: ownerUserStoreId)
            .whereField("isShared", isEqualTo: true)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }

                if let error = error {
                    #if DEBUG
                    print("FriendsService: Error fetching reminders to clean up: \(error.localizedDescription)")
                    #endif
                    return
                }

                guard let documents = snapshot?.documents, !documents.isEmpty else {
                    return
                }

                let batch = self.db.batch()
                var updatedCount = 0

                for doc in documents {
                    let data = doc.data()
                    var sharedWith = data["sharedWith"] as? [String] ?? []
                    let sharedFrom = data["sharedFrom"] as? String

                    // Reminder was created by the recipient and added to the owner's store.
                    // Delete it entirely — it was their item and they are being removed.
                    if sharedFrom == recipientName {
                        batch.deleteDocument(doc.reference)
                        updatedCount += 1
                        continue
                    }

                    // Reminder shared with the recipient — remove them from sharedWith
                    if sharedWith.contains(recipientName) {
                        sharedWith.removeAll { $0 == recipientName }
                        updatedCount += 1
                        if sharedWith.isEmpty {
                            batch.updateData([
                                "isShared": false,
                                "sharedWith": FieldValue.delete(),
                                "sharedFrom": FieldValue.delete()
                            ], forDocument: doc.reference)
                        } else {
                            batch.updateData([
                                "sharedWith": sharedWith
                            ], forDocument: doc.reference)
                        }
                    }
                }

                if updatedCount > 0 {
                    batch.commit { error in
                        #if DEBUG
                        if let error = error {
                            print("FriendsService: Error updating reminders after unshare: \(error.localizedDescription)")
                        } else {
                            print("FriendsService: Updated \(updatedCount) reminder(s) after unshare")
                        }
                        #endif
                    }
                }
            }
    }

    /// Cleans up reminder items in a merged store when the sharing relationship is broken.
    /// Deletes items that came from the owner, and removes the owner from sharedWith on the
    /// merged-store owner's own reminders.
    private func cleanUpMergedStoreRemindersOnUnshare(mergedStoreId: String, ownerUserId: String, ownerName: String) {
        db.collection("reminders")
            .whereField("userStoreId", isEqualTo: mergedStoreId)
            .whereField("isShared", isEqualTo: true)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self,
                      let documents = snapshot?.documents, !documents.isEmpty else { return }

                let batch = self.db.batch()
                var count = 0

                for doc in documents {
                    let data = doc.data()
                    let sharedFromId = data["sharedFromId"] as? String
                    var sharedWith = data["sharedWith"] as? [String] ?? []

                    if sharedFromId == ownerUserId {
                        // Came from the owner during merge — delete it
                        batch.deleteDocument(doc.reference)
                        count += 1
                    } else if sharedWith.contains(ownerName) {
                        // Merged-store owner's item shared WITH the original owner — remove them
                        sharedWith.removeAll { $0 == ownerName }
                        if sharedWith.isEmpty {
                            batch.updateData([
                                "isShared": false,
                                "sharedWith": FieldValue.delete()
                            ], forDocument: doc.reference)
                        } else {
                            batch.updateData(["sharedWith": sharedWith], forDocument: doc.reference)
                        }
                        count += 1
                    }
                }

                if count > 0 {
                    batch.commit { error in
                        #if DEBUG
                        if let error = error {
                            print("FriendsService: Error cleaning merged store reminders: \(error.localizedDescription)")
                        } else {
                            print("FriendsService: Cleaned \(count) reminder(s) in merged store \(mergedStoreId)")
                        }
                        #endif
                    }
                }
            }
    }

    // MARK: - Search Users

    /// Search for users by email
    func searchUserByEmail(
        _ email: String,
        excludeUserId: String,
        completion: @escaping (Result<Contact?, Error>) -> Void
    ) {
        db.collection("users")
            .whereField("email", isEqualTo: email.lowercased())
            .limit(to: 1)
            .getDocuments { snapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }

                guard let doc = snapshot?.documents.first else {
                    completion(.success(nil))
                    return
                }

                let data = doc.data()
                guard let name = data["name"] as? String,
                      let email = data["email"] as? String else {
                    completion(.success(nil))
                    return
                }

                let userId = data["userId"] as? String ?? doc.documentID

                // Don't return the current user
                if userId == excludeUserId {
                    completion(.success(nil))
                    return
                }

                let contact = Contact(
                    id: userId,
                    name: name,
                    email: email,
                    profilePictureURL: data["profilePictureURL"] as? String
                )

                completion(.success(contact))
            }
    }

    /// Search for users by username (userId)
    func searchUserByUsername(
        _ username: String,
        excludeUserId: String,
        completion: @escaping (Result<Contact?, Error>) -> Void
    ) {
        let normalizedUsername = username.lowercased()

        db.collection("users").document(normalizedUsername).getDocument { snapshot, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = snapshot?.data(),
                  let name = data["name"] as? String,
                  let email = data["email"] as? String else {
                completion(.success(nil))
                return
            }

            let userId = data["userId"] as? String ?? normalizedUsername

            // Don't return the current user
            if userId == excludeUserId {
                completion(.success(nil))
                return
            }

            let contact = Contact(
                id: userId,
                name: name,
                email: email,
                profilePictureURL: data["profilePictureURL"] as? String
            )

            completion(.success(contact))
        }
    }

    // MARK: - Pending Request Count

    /// Get the count of pending friend requests for badge
    func getPendingRequestCount(
        for userId: String,
        completion: @escaping (Int) -> Void
    ) -> ListenerRegistration {
        return db.collection("friends")
            .whereField("receiverId", isEqualTo: userId)
            .whereField("status", isEqualTo: FriendshipStatus.pending.rawValue)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    #if DEBUG
                    print("FriendsService: Error getting pending count: \(error)")
                    #endif
                    completion(0)
                    return
                }

                completion(snapshot?.documents.count ?? 0)
            }
    }

    // MARK: - Parsing Helpers

    private func parseFriendship(from doc: QueryDocumentSnapshot) -> Friendship? {
        let data = doc.data()

        guard let requesterId = data["requesterId"] as? String,
              let requesterName = data["requesterName"] as? String,
              let requesterEmail = data["requesterEmail"] as? String,
              let receiverId = data["receiverId"] as? String,
              let receiverName = data["receiverName"] as? String,
              let receiverEmail = data["receiverEmail"] as? String,
              let statusString = data["status"] as? String,
              let status = FriendshipStatus(rawValue: statusString),
              let createdAt = data["createdAt"] as? TimeInterval else {
            return nil
        }

        return Friendship(
            id: doc.documentID,
            requesterId: requesterId,
            requesterName: requesterName,
            requesterEmail: requesterEmail,
            requesterProfilePictureURL: data["requesterProfilePictureURL"] as? String,
            receiverId: receiverId,
            receiverName: receiverName,
            receiverEmail: receiverEmail,
            receiverProfilePictureURL: data["receiverProfilePictureURL"] as? String,
            status: status,
            createdAt: createdAt,
            acceptedAt: data["acceptedAt"] as? TimeInterval
        )
    }

    private func parseFriendship(from doc: DocumentSnapshot) -> Friendship? {
        guard let data = doc.data() else { return nil }

        guard let requesterId = data["requesterId"] as? String,
              let requesterName = data["requesterName"] as? String,
              let requesterEmail = data["requesterEmail"] as? String,
              let receiverId = data["receiverId"] as? String,
              let receiverName = data["receiverName"] as? String,
              let receiverEmail = data["receiverEmail"] as? String,
              let statusString = data["status"] as? String,
              let status = FriendshipStatus(rawValue: statusString),
              let createdAt = data["createdAt"] as? TimeInterval else {
            return nil
        }

        return Friendship(
            id: doc.documentID,
            requesterId: requesterId,
            requesterName: requesterName,
            requesterEmail: requesterEmail,
            requesterProfilePictureURL: data["requesterProfilePictureURL"] as? String,
            receiverId: receiverId,
            receiverName: receiverName,
            receiverEmail: receiverEmail,
            receiverProfilePictureURL: data["receiverProfilePictureURL"] as? String,
            status: status,
            createdAt: createdAt,
            acceptedAt: data["acceptedAt"] as? TimeInterval
        )
    }
}
