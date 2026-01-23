//
//  FriendsViewModel.swift
//  Geolocation_v1.0.0
//
//  Created by Claude Code
//

import Foundation
import FirebaseFirestore

class FriendsViewModel: ObservableObject {
    @Published var friends: [Friendship] = []
    @Published var pendingRequests: [Friendship] = []
    @Published var sentRequests: [Friendship] = []
    @Published var searchedUser: Contact?
    @Published var isLoading = false
    @Published var isSearching = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var pendingRequestCount = 0

    private let friendsService = FriendsService.shared
    private var friendshipsListener: ListenerRegistration?
    private var pendingCountListener: ListenerRegistration?

    private var currentUserId: String? {
        UserSessionManager.shared.currentUser?.userId
    }

    deinit {
        stopListening()
    }

    // MARK: - Fetch Data

    func fetchFriendships() {
        guard let userId = currentUserId else { return }
        isLoading = true

        // Remove existing listener
        friendshipsListener?.remove()

        friendshipsListener = friendsService.fetchFriendships(for: userId) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false

                switch result {
                case .success(let friendships):
                    self.processFriendships(friendships, currentUserId: userId)
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                    print("FriendsViewModel: Error fetching friendships: \(error)")
                }
            }
        }
    }

    func fetchPendingRequestCount() {
        guard let userId = currentUserId else { return }

        pendingCountListener?.remove()

        pendingCountListener = friendsService.getPendingRequestCount(for: userId) { [weak self] count in
            DispatchQueue.main.async {
                self?.pendingRequestCount = count
            }
        }
    }

    private func processFriendships(_ friendships: [Friendship], currentUserId: String) {
        var acceptedFriends: [Friendship] = []
        var pending: [Friendship] = []
        var sent: [Friendship] = []

        for friendship in friendships {
            switch friendship.status {
            case .accepted:
                acceptedFriends.append(friendship)
            case .pending:
                if friendship.receiverId == currentUserId {
                    // Request received
                    pending.append(friendship)
                } else {
                    // Request sent
                    sent.append(friendship)
                }
            case .rejected:
                // Don't show rejected friendships
                break
            }
        }

        // Sort by name
        self.friends = acceptedFriends.sorted { $0.friendName(currentUserId: currentUserId) < $1.friendName(currentUserId: currentUserId) }
        self.pendingRequests = pending.sorted { $0.createdAt > $1.createdAt }
        self.sentRequests = sent.sorted { $0.createdAt > $1.createdAt }
    }

    func stopListening() {
        friendshipsListener?.remove()
        friendshipsListener = nil
        pendingCountListener?.remove()
        pendingCountListener = nil
    }

    // MARK: - Search Users

    func searchUser(query: String) {
        guard !query.isEmpty,
              let userId = currentUserId else {
            searchedUser = nil
            return
        }

        isSearching = true
        searchedUser = nil

        // Check if query looks like an email
        if query.contains("@") {
            friendsService.searchUserByEmail(query, excludeUserId: userId) { [weak self] result in
                DispatchQueue.main.async {
                    self?.isSearching = false
                    switch result {
                    case .success(let contact):
                        self?.searchedUser = contact
                    case .failure(let error):
                        self?.errorMessage = error.localizedDescription
                    }
                }
            }
        } else {
            // Search by username
            friendsService.searchUserByUsername(query, excludeUserId: userId) { [weak self] result in
                DispatchQueue.main.async {
                    self?.isSearching = false
                    switch result {
                    case .success(let contact):
                        self?.searchedUser = contact
                    case .failure(let error):
                        self?.errorMessage = error.localizedDescription
                    }
                }
            }
        }
    }

    // MARK: - Friend Actions

    func sendFriendRequest(to contact: Contact) {
        guard let user = UserSessionManager.shared.currentUser else {
            errorMessage = "User not logged in"
            return
        }

        // Check if already friends or request exists
        if let existing = findExistingRelationship(with: contact.id) {
            if existing.status == .accepted {
                errorMessage = "You're already friends with \(contact.name)"
            } else if existing.status == .pending {
                if existing.isRequester(currentUserId: user.userId) {
                    errorMessage = "Friend request already sent to \(contact.name)"
                } else {
                    errorMessage = "\(contact.name) already sent you a friend request"
                }
            }
            return
        }

        isLoading = true

        friendsService.sendFriendRequest(from: user, to: contact) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                switch result {
                case .success:
                    self?.successMessage = "Friend request sent to \(contact.name)"
                    self?.searchedUser = nil
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func acceptRequest(_ friendship: Friendship) {
        friendsService.acceptFriendRequest(friendshipId: friendship.id) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.successMessage = "You are now friends with \(friendship.requesterName)"
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func rejectRequest(_ friendship: Friendship) {
        friendsService.rejectFriendRequest(friendshipId: friendship.id) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.successMessage = "Friend request declined"
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func removeFriend(_ friendship: Friendship) {
        guard let userId = currentUserId else { return }
        let friendName = friendship.friendName(currentUserId: userId)

        friendsService.removeFriend(friendshipId: friendship.id) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.successMessage = "\(friendName) removed from friends"
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func cancelRequest(_ friendship: Friendship) {
        friendsService.removeFriend(friendshipId: friendship.id) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.successMessage = "Friend request cancelled"
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }

    // MARK: - Helpers

    private func findExistingRelationship(with userId: String) -> Friendship? {
        // Check in all lists
        if let existing = friends.first(where: { $0.requesterId == userId || $0.receiverId == userId }) {
            return existing
        }
        if let existing = pendingRequests.first(where: { $0.requesterId == userId || $0.receiverId == userId }) {
            return existing
        }
        if let existing = sentRequests.first(where: { $0.requesterId == userId || $0.receiverId == userId }) {
            return existing
        }
        return nil
    }

    func getRelationshipStatus(with userId: String) -> (exists: Bool, status: FriendshipStatus?, isSentByMe: Bool) {
        guard let currentUserId = currentUserId else {
            return (false, nil, false)
        }

        if let friendship = findExistingRelationship(with: userId) {
            return (true, friendship.status, friendship.isRequester(currentUserId: currentUserId))
        }
        return (false, nil, false)
    }

    func clearMessages() {
        errorMessage = nil
        successMessage = nil
    }

    /// Get accepted friends as contacts for messaging/sharing
    func getAcceptedFriendsAsContacts() -> [Contact] {
        guard let userId = currentUserId else { return [] }
        return friends.map { $0.toContact(currentUserId: userId) }
    }
}
