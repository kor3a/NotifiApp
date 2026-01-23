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
        // Query for friendships where user is either requester or receiver
        // Using two queries and merging results
        let listener = db.collection("friends")
            .whereField("participantIds", arrayContains: userId)
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
                    print("FriendsService: Error checking existing friendship: \(error)")
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
        db.collection("friends").document(friendshipId).delete { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
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
                    print("FriendsService: Error getting pending count: \(error)")
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
