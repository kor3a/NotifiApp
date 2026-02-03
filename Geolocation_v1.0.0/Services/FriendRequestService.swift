//
//  FriendRequestService.swift
//  Geolocation_v1.0.0
//
//  Created by Claude Code
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

class FriendRequestService: ObservableObject {
    static let shared = FriendRequestService()

    private let db = Firestore.firestore()

    @Published var incomingRequests: [FriendRequest] = []
    @Published var outgoingRequests: [FriendRequest] = []
    @Published var pendingRequestCount: Int = 0

    private var incomingListener: ListenerRegistration?
    private var outgoingListener: ListenerRegistration?
    private var knownRequestIds: Set<String> = []

    private init() {}

    // MARK: - Send Friend Request

    /// Send a friend request to a user by email
    func sendFriendRequest(
        toEmail: String,
        fromUser: User,
        completion: @escaping (Result<FriendRequest, Error>) -> Void
    ) {
        let normalizedEmail = toEmail.lowercased().trimmingCharacters(in: .whitespaces)

        // Don't allow sending request to self
        guard normalizedEmail != fromUser.email.lowercased() else {
            completion(.failure(NSError(domain: "FriendRequestService", code: -1, userInfo: [NSLocalizedDescriptionKey: "You cannot send a friend request to yourself"])))
            return
        }

        // First find the user by email
        db.collection("users")
            .whereField("email", isEqualTo: normalizedEmail)
            .limit(to: 1)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }

                if let error = error {
                    completion(.failure(error))
                    return
                }

                guard let doc = snapshot?.documents.first else {
                    completion(.failure(NSError(domain: "FriendRequestService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No user found with that email address"])))
                    return
                }

                let data = doc.data()
                guard let toUserId = data["userId"] as? String ?? Optional(doc.documentID),
                      let toUserName = data["name"] as? String else {
                    completion(.failure(NSError(domain: "FriendRequestService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid user data"])))
                    return
                }

                let toUserEmail = data["email"] as? String ?? normalizedEmail
                let toUserProfilePictureURL = data["profilePictureURL"] as? String

                // Check if a request already exists between these users
                self.checkExistingRequest(fromUserId: fromUser.userId, toUserId: toUserId) { existingRequest in
                    if let existing = existingRequest {
                        if existing.status == .pending {
                            completion(.failure(NSError(domain: "FriendRequestService", code: -1, userInfo: [NSLocalizedDescriptionKey: "A friend request is already pending with this user"])))
                        } else if existing.status == .accepted {
                            completion(.failure(NSError(domain: "FriendRequestService", code: -1, userInfo: [NSLocalizedDescriptionKey: "You are already friends with this user"])))
                        } else {
                            // Previous request was rejected, allow sending again
                            self.createFriendRequest(
                                fromUser: fromUser,
                                toUserId: toUserId,
                                toUserName: toUserName,
                                toUserEmail: toUserEmail,
                                toUserProfilePictureURL: toUserProfilePictureURL,
                                completion: completion
                            )
                        }
                    } else {
                        // No existing request, create new one
                        self.createFriendRequest(
                            fromUser: fromUser,
                            toUserId: toUserId,
                            toUserName: toUserName,
                            toUserEmail: toUserEmail,
                            toUserProfilePictureURL: toUserProfilePictureURL,
                            completion: completion
                        )
                    }
                }
            }
    }

    private func checkExistingRequest(fromUserId: String, toUserId: String, completion: @escaping (FriendRequest?) -> Void) {
        // Check for request in either direction
        db.collection("friend_requests")
            .whereField("fromUserId", isEqualTo: fromUserId)
            .whereField("toUserId", isEqualTo: toUserId)
            .limit(to: 1)
            .getDocuments { [weak self] snapshot, error in
                if let doc = snapshot?.documents.first, let request = self?.parseFriendRequest(from: doc) {
                    completion(request)
                    return
                }

                // Check reverse direction
                self?.db.collection("friend_requests")
                    .whereField("fromUserId", isEqualTo: toUserId)
                    .whereField("toUserId", isEqualTo: fromUserId)
                    .limit(to: 1)
                    .getDocuments { snapshot, error in
                        if let doc = snapshot?.documents.first, let request = self?.parseFriendRequest(from: doc) {
                            completion(request)
                        } else {
                            completion(nil)
                        }
                    }
            }
    }

    private func createFriendRequest(
        fromUser: User,
        toUserId: String,
        toUserName: String,
        toUserEmail: String,
        toUserProfilePictureURL: String?,
        completion: @escaping (Result<FriendRequest, Error>) -> Void
    ) {
        let now = Date().timeIntervalSince1970

        var requestData: [String: Any] = [
            "fromUserId": fromUser.userId,
            "toUserId": toUserId,
            "fromUserName": fromUser.name,
            "toUserName": toUserName,
            "fromUserEmail": fromUser.email,
            "toUserEmail": toUserEmail,
            "status": FriendRequestStatus.pending.rawValue,
            "createdAt": now
        ]

        if let fromProfilePic = fromUser.profilePictureURL {
            requestData["fromUserProfilePictureURL"] = fromProfilePic
        }

        if let toProfilePic = toUserProfilePictureURL {
            requestData["toUserProfilePictureURL"] = toProfilePic
        }

        var ref: DocumentReference?
        ref = db.collection("friend_requests").addDocument(data: requestData) { error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let docId = ref?.documentID else {
                completion(.failure(NSError(domain: "FriendRequestService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create friend request"])))
                return
            }

            let request = FriendRequest(
                id: docId,
                fromUserId: fromUser.userId,
                toUserId: toUserId,
                fromUserName: fromUser.name,
                toUserName: toUserName,
                fromUserEmail: fromUser.email,
                toUserEmail: toUserEmail,
                status: .pending,
                createdAt: now,
                fromUserProfilePictureURL: fromUser.profilePictureURL,
                toUserProfilePictureURL: toUserProfilePictureURL
            )

            print("FriendRequestService: Created friend request from \(fromUser.name) to \(toUserName)")
            completion(.success(request))
        }
    }

    // MARK: - Accept/Reject Friend Request

    /// Accept a friend request
    func acceptFriendRequest(requestId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        db.collection("friend_requests").document(requestId).updateData([
            "status": FriendRequestStatus.accepted.rawValue
        ]) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                print("FriendRequestService: Accepted friend request \(requestId)")
                completion(.success(()))
            }
        }
    }

    /// Reject a friend request
    func rejectFriendRequest(requestId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        db.collection("friend_requests").document(requestId).updateData([
            "status": FriendRequestStatus.rejected.rawValue
        ]) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                print("FriendRequestService: Rejected friend request \(requestId)")
                completion(.success(()))
            }
        }
    }

    // MARK: - Remove Friend

    /// Remove a friend by deleting the friend request document
    func removeFriend(currentUserId: String, friendUserId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        // Find the friend request document (could be in either direction)
        let group = DispatchGroup()
        var foundDocId: String?
        var fetchError: Error?

        // Check if current user sent the request
        group.enter()
        db.collection("friend_requests")
            .whereField("fromUserId", isEqualTo: currentUserId)
            .whereField("toUserId", isEqualTo: friendUserId)
            .limit(to: 1)
            .getDocuments { snapshot, error in
                if let error = error {
                    fetchError = error
                } else if let doc = snapshot?.documents.first {
                    foundDocId = doc.documentID
                }
                group.leave()
            }

        // Check if friend sent the request
        group.enter()
        db.collection("friend_requests")
            .whereField("fromUserId", isEqualTo: friendUserId)
            .whereField("toUserId", isEqualTo: currentUserId)
            .limit(to: 1)
            .getDocuments { snapshot, error in
                if let error = error, fetchError == nil {
                    fetchError = error
                } else if let doc = snapshot?.documents.first, foundDocId == nil {
                    foundDocId = doc.documentID
                }
                group.leave()
            }

        group.notify(queue: .main) { [weak self] in
            guard let self = self else { return }

            if let error = fetchError {
                completion(.failure(error))
                return
            }

            guard let docId = foundDocId else {
                completion(.failure(NSError(domain: "FriendRequestService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Friend relationship not found"])))
                return
            }

            // Delete the friend request document
            self.db.collection("friend_requests").document(docId).delete { error in
                if let error = error {
                    print("FriendRequestService: Error removing friend: \(error)")
                    completion(.failure(error))
                } else {
                    // Also remove from knownRequestIds so if they send a new request, we get notified
                    self.knownRequestIds.remove(docId)
                    print("FriendRequestService: Successfully removed friend (deleted request \(docId))")
                    completion(.success(()))
                }
            }
        }
    }

    /// Remove a friend request by its ID (for direct deletion)
    func removeFriendRequest(requestId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        db.collection("friend_requests").document(requestId).delete { [weak self] error in
            if let error = error {
                print("FriendRequestService: Error removing friend request: \(error)")
                completion(.failure(error))
            } else {
                // Also remove from knownRequestIds
                self?.knownRequestIds.remove(requestId)
                print("FriendRequestService: Successfully removed friend request \(requestId)")
                completion(.success(()))
            }
        }
    }

    // MARK: - Listeners

    /// Start listening for incoming friend requests (requests sent TO the current user)
    /// Listens to the 'friends' collection where pending requests have receiverId = userId
    func listenForIncomingRequests(userId: String) {
        // Remove existing listener
        incomingListener?.remove()

        print("FriendRequestService: Setting up listener for incoming friend requests (friends collection) for userId: \(userId)")

        // Listen to 'friends' collection for pending requests where user is the receiver
        incomingListener = db.collection("friends")
            .whereField("receiverId", isEqualTo: userId)
            .whereField("status", isEqualTo: "pending")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }

                if let error = error {
                    print("FriendRequestService: Error listening for incoming requests: \(error)")
                    return
                }

                guard let documents = snapshot?.documents else {
                    DispatchQueue.main.async {
                        self.incomingRequests = []
                        self.pendingRequestCount = 0
                    }
                    print("FriendRequestService: No pending friend requests found")
                    return
                }

                print("FriendRequestService: Received \(documents.count) pending friend request documents")

                // Check for new requests to trigger notifications
                for doc in documents {
                    let requestId = doc.documentID
                    if !self.knownRequestIds.contains(requestId) {
                        // This is a new request, trigger notification
                        self.knownRequestIds.insert(requestId)

                        let data = doc.data()
                        let fromUserName = data["requesterName"] as? String ?? "Someone"

                        print("FriendRequestService: NEW friend request detected from \(fromUserName), scheduling notification...")
                        NotificationManager.shared.scheduleFriendRequestNotification(
                            fromUserName: fromUserName
                        )
                    }
                }

                // Parse documents into FriendRequest format for compatibility
                let requests = documents.compactMap { doc -> FriendRequest? in
                    let data = doc.data()
                    guard let requesterId = data["requesterId"] as? String,
                          let requesterName = data["requesterName"] as? String,
                          let requesterEmail = data["requesterEmail"] as? String,
                          let receiverId = data["receiverId"] as? String,
                          let receiverName = data["receiverName"] as? String,
                          let receiverEmail = data["receiverEmail"] as? String,
                          let createdAt = data["createdAt"] as? TimeInterval else {
                        return nil
                    }

                    return FriendRequest(
                        id: doc.documentID,
                        fromUserId: requesterId,
                        toUserId: receiverId,
                        fromUserName: requesterName,
                        toUserName: receiverName,
                        fromUserEmail: requesterEmail,
                        toUserEmail: receiverEmail,
                        status: .pending,
                        createdAt: createdAt,
                        fromUserProfilePictureURL: data["requesterProfilePictureURL"] as? String,
                        toUserProfilePictureURL: data["receiverProfilePictureURL"] as? String
                    )
                }

                DispatchQueue.main.async {
                    self.incomingRequests = requests
                    self.pendingRequestCount = requests.count
                }

                print("FriendRequestService: Found \(requests.count) pending incoming friend requests")
            }
    }

    /// Start listening for outgoing friend requests (requests sent BY the current user)
    func listenForOutgoingRequests(userId: String) {
        // Remove existing listener
        outgoingListener?.remove()

        print("FriendRequestService: Setting up listener for outgoing requests for userId: \(userId)")

        outgoingListener = db.collection("friend_requests")
            .whereField("fromUserId", isEqualTo: userId)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }

                if let error = error {
                    print("FriendRequestService: Error listening for outgoing requests: \(error)")
                    return
                }

                guard let documents = snapshot?.documents else {
                    self.outgoingRequests = []
                    return
                }

                let requests = documents.compactMap { self.parseFriendRequest(from: $0) }

                DispatchQueue.main.async {
                    self.outgoingRequests = requests
                }

                print("FriendRequestService: Found \(requests.count) outgoing requests")
            }
    }

    /// Stop all listeners
    func stopListening() {
        incomingListener?.remove()
        outgoingListener?.remove()
        incomingListener = nil
        outgoingListener = nil
        knownRequestIds.removeAll()
    }

    // MARK: - Get Friends

    /// Get list of accepted friends for the user
    func getFriends(userId: String, completion: @escaping (Result<[Contact], Error>) -> Void) {
        // Get requests where user is either sender or receiver and status is accepted
        let group = DispatchGroup()
        var allFriendIds: [String] = []
        var friendNames: [String: String] = [:]
        var friendProfilePics: [String: String?] = [:]
        var friendEmails: [String: String] = [:]

        // Requests sent by user
        group.enter()
        db.collection("friend_requests")
            .whereField("fromUserId", isEqualTo: userId)
            .whereField("status", isEqualTo: FriendRequestStatus.accepted.rawValue)
            .getDocuments { snapshot, error in
                if let docs = snapshot?.documents {
                    for doc in docs {
                        let data = doc.data()
                        if let friendId = data["toUserId"] as? String {
                            allFriendIds.append(friendId)
                            friendNames[friendId] = data["toUserName"] as? String ?? "Unknown"
                            friendProfilePics[friendId] = data["toUserProfilePictureURL"] as? String
                            friendEmails[friendId] = data["toUserEmail"] as? String ?? ""
                        }
                    }
                }
                group.leave()
            }

        // Requests received by user
        group.enter()
        db.collection("friend_requests")
            .whereField("toUserId", isEqualTo: userId)
            .whereField("status", isEqualTo: FriendRequestStatus.accepted.rawValue)
            .getDocuments { snapshot, error in
                if let docs = snapshot?.documents {
                    for doc in docs {
                        let data = doc.data()
                        if let friendId = data["fromUserId"] as? String {
                            allFriendIds.append(friendId)
                            friendNames[friendId] = data["fromUserName"] as? String ?? "Unknown"
                            friendProfilePics[friendId] = data["fromUserProfilePictureURL"] as? String
                            friendEmails[friendId] = data["fromUserEmail"] as? String ?? ""
                        }
                    }
                }
                group.leave()
            }

        group.notify(queue: .main) {
            // Remove duplicates and create Contact array
            let uniqueFriendIds = Array(Set(allFriendIds))
            let contacts = uniqueFriendIds.map { friendId in
                Contact(
                    id: friendId,
                    name: friendNames[friendId] ?? "Unknown",
                    email: friendEmails[friendId] ?? "",
                    profilePictureURL: friendProfilePics[friendId] ?? nil
                )
            }
            completion(.success(contacts))
        }
    }

    // MARK: - Parsing

    private func parseFriendRequest(from doc: QueryDocumentSnapshot) -> FriendRequest? {
        let data = doc.data()

        guard let fromUserId = data["fromUserId"] as? String,
              let toUserId = data["toUserId"] as? String,
              let fromUserName = data["fromUserName"] as? String,
              let toUserName = data["toUserName"] as? String,
              let fromUserEmail = data["fromUserEmail"] as? String,
              let toUserEmail = data["toUserEmail"] as? String,
              let statusString = data["status"] as? String,
              let status = FriendRequestStatus(rawValue: statusString),
              let createdAt = data["createdAt"] as? TimeInterval else {
            return nil
        }

        return FriendRequest(
            id: doc.documentID,
            fromUserId: fromUserId,
            toUserId: toUserId,
            fromUserName: fromUserName,
            toUserName: toUserName,
            fromUserEmail: fromUserEmail,
            toUserEmail: toUserEmail,
            status: status,
            createdAt: createdAt,
            fromUserProfilePictureURL: data["fromUserProfilePictureURL"] as? String,
            toUserProfilePictureURL: data["toUserProfilePictureURL"] as? String
        )
    }
}
