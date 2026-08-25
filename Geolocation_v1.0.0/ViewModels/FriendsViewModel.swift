//
//  FriendsViewModel.swift
//  Geolocation_v1.0.0
//
//  Created by Claude Code
//

import Foundation
import FirebaseFirestore
import Combine

class FriendsViewModel: ObservableObject {
    @Published var friends: [Friendship] = []
    @Published var familyMembers: [Friendship] = []
    @Published var pendingRequests: [Friendship] = []
    @Published var sentRequests: [Friendship] = []
    @Published var searchedUser: Contact?
    @Published var isLoading = false
    @Published var isSearching = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var pendingRequestCount = 0

    /// Text typed into the Friends tab search bar. It filters the `filtered*`
    /// section lists only — `friends`, `familyMembers`, `pendingRequests` and
    /// `sentRequests` stay complete for the other screens that read them.
    @Published var searchText: String = ""

    /// Fresh profile picture URLs keyed by userId, fetched directly from the `users` collection.
    @Published var friendProfilePictures: [String: String] = [:]

    private let friendsService = FriendsService.shared
    private var friendshipsListener: ListenerRegistration?
    private var pendingCountListener: ListenerRegistration?
    private var cancellables = Set<AnyCancellable>()

    private var currentUserId: String? {
        UserSessionManager.shared.currentUser?.userId
    }

    init() {
        TutorialManager.shared.$isActive
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isActive in
                if isActive {
                    self?.loadTutorialMockData()
                } else {
                    self?.clearTutorialMockData()
                    self?.fetchFriendships()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Tutorial Mock Data

    private func loadTutorialMockData() {
        friendshipsListener?.remove()
        friendshipsListener = nil
        isLoading = false
        // Bypass processFriendships — directly assign family and friends sections
        familyMembers = TutorialMockData.familyFriendships
        friends = TutorialMockData.friendFriendships
        pendingRequests = []
        sentRequests = []
    }

    private func clearTutorialMockData() {
        friendshipsListener?.remove()
        friendshipsListener = nil
        familyMembers = []
        friends = []
        pendingRequests = []
        sentRequests = []
    }

    deinit {
        stopListening()
    }

    // MARK: - Fetch Data

    func fetchFriendships() {
        guard !TutorialManager.shared.isActive else {
            loadTutorialMockData()
            return
        }
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
                    self.fetchFriendProfilePictures(from: friendships, currentUserId: userId)
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                    #if DEBUG
                    print("FriendsViewModel: Error fetching friendships: \(error)")
                    #endif
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

        // Separate family members from regular friends
        let familyIds = UserSessionManager.shared.currentUser?.familyMemberIds ?? []
        var family: [Friendship] = []
        var nonFamily: [Friendship] = []

        for friendship in acceptedFriends {
            let friendId = friendship.friendId(currentUserId: currentUserId)
            if familyIds.contains(friendId) {
                family.append(friendship)
            } else {
                nonFamily.append(friendship)
            }
        }

        // Friends and family read as an alphabetical list; requests stay
        // newest-first so the most recent one is the first thing to answer.
        self.familyMembers = sortedByFriendName(family, currentUserId: currentUserId)
        self.friends = sortedByFriendName(nonFamily, currentUserId: currentUserId)
        self.pendingRequests = pending.sorted { $0.createdAt > $1.createdAt }
        self.sentRequests = sent.sorted { $0.createdAt > $1.createdAt }

        // Warm the avatar cache off the friendship documents so the photos are
        // decoded before the list draws rather than fading in after it.
        ProfileImageCache.shared.prefetch(
            (family + nonFamily + pending + sent).map {
                $0.friendProfilePictureURL(currentUserId: currentUserId)
            }
        )
    }

    /// Sort friendships alphabetically by the other user's display name, falling
    /// back to their user ID so equal names keep a stable order between updates.
    private func sortedByFriendName(_ friendships: [Friendship], currentUserId: String) -> [Friendship] {
        friendships.sorted { lhs, rhs in
            let lhsName = lhs.friendName(currentUserId: currentUserId)
            let rhsName = rhs.friendName(currentUserId: currentUserId)
            let comparison = lhsName.localizedCaseInsensitiveCompare(rhsName)
            if comparison == .orderedSame {
                return lhs.friendId(currentUserId: currentUserId) < rhs.friendId(currentUserId: currentUserId)
            }
            return comparison == .orderedAscending
        }
    }

    func stopListening() {
        friendshipsListener?.remove()
        friendshipsListener = nil
        pendingCountListener?.remove()
        pendingCountListener = nil
    }

    // MARK: - Profile Pictures

    /// Fetch fresh profile picture URLs from the `users` collection for all friend user IDs.
    private func fetchFriendProfilePictures(from friendships: [Friendship], currentUserId: String) {
        // Collect all unique friend user IDs (requester or receiver, whichever is not us)
        var userIds: Set<String> = []
        for friendship in friendships {
            let friendId = friendship.friendId(currentUserId: currentUserId)
            userIds.insert(friendId)
        }

        guard !userIds.isEmpty else { return }

        let db = Firestore.firestore()
        let idsArray = Array(userIds)
        // Firestore 'in' queries limited to 30 items; batch if needed
        let batches = stride(from: 0, to: idsArray.count, by: 30).map {
            Array(idsArray[$0..<min($0 + 30, idsArray.count)])
        }

        for batch in batches {
            db.collection("users")
                .whereField(FieldPath.documentID(), in: batch)
                .getDocuments { [weak self] snapshot, error in
                    guard let documents = snapshot?.documents else { return }

                    DispatchQueue.main.async {
                        for doc in documents {
                            if let url = doc.data()["profilePictureURL"] as? String {
                                self?.friendProfilePictures[doc.documentID] = url
                            }
                        }
                    }
                }
        }
    }

    // MARK: - Friend Search Filtering

    private var trimmedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Whether the user is currently narrowing the list with the search bar.
    var isFilteringFriends: Bool {
        !trimmedSearchText.isEmpty
    }

    /// Received friend requests matching the search text.
    var filteredPendingRequests: [Friendship] {
        filterFriendships(pendingRequests) { [$0.requesterName, $0.requesterEmail, $0.requesterId] }
    }

    /// Sent friend requests matching the search text.
    var filteredSentRequests: [Friendship] {
        filterFriendships(sentRequests) { [$0.receiverName, $0.receiverEmail, $0.receiverId] }
    }

    /// Family members matching the search text.
    var filteredFamilyMembers: [Friendship] {
        filterFriendships(familyMembers, fields: friendSearchFields)
    }

    /// Non-family friends matching the search text.
    var filteredFriends: [Friendship] {
        filterFriendships(friends, fields: friendSearchFields)
    }

    /// True when a search is active but nothing in any section matches it.
    var hasNoSearchResults: Bool {
        isFilteringFriends
            && filteredPendingRequests.isEmpty
            && filteredSentRequests.isEmpty
            && filteredFamilyMembers.isEmpty
            && filteredFriends.isEmpty
    }

    private func friendSearchFields(_ friendship: Friendship) -> [String] {
        let userId = currentUserId ?? ""
        return [
            friendship.friendName(currentUserId: userId),
            friendship.friendEmail(currentUserId: userId),
            friendship.friendId(currentUserId: userId)
        ]
    }

    private func filterFriendships(
        _ friendships: [Friendship],
        fields: (Friendship) -> [String]
    ) -> [Friendship] {
        let query = trimmedSearchText
        guard !query.isEmpty else { return friendships }

        return friendships.filter { friendship in
            fields(friendship).contains { field in
                field.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) != nil
            }
        }
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
        guard !TutorialManager.shared.isActive else { return }
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
        guard !TutorialManager.shared.isActive else { return }
        guard let userId = currentUserId,
              let currentUserName = UserSessionManager.shared.currentUser?.name else {
            #if DEBUG
            print("FriendsViewModel: Cannot remove friend - no current user data")
            #endif
            return
        }
        let friendId = friendship.friendId(currentUserId: userId)
        let friendName = friendship.friendName(currentUserId: userId)

        #if DEBUG
        print("FriendsViewModel: Removing friend '\(friendName)' with friendship ID: \(friendship.id)")
        #endif

        // First, unshare all stores between the two users
        friendsService.unshareAllStoresBetweenUsers(
            currentUserId: userId,
            currentUserName: currentUserName,
            friendId: friendId,
            friendName: friendName
        ) { [weak self] unshareResult in
            #if DEBUG
            switch unshareResult {
            case .success(let count):
                print("FriendsViewModel: Unshared \(count) store(s) with '\(friendName)'")
            case .failure(let error):
                print("FriendsViewModel: Error unsharing stores with '\(friendName)': \(error.localizedDescription)")
            }
            #endif

            // Then remove the friendship regardless of unshare result
            self?.friendsService.removeFriend(friendshipId: friendship.id) { [weak self] result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        #if DEBUG
                        print("FriendsViewModel: Successfully removed friend '\(friendName)'")
                        #endif
                        if case .success(let count) = unshareResult, count > 0 {
                            self?.successMessage = "\(friendName) removed from friends and \(count) shared store(s) unshared"
                        } else {
                            self?.successMessage = "\(friendName) removed from friends"
                        }
                    case .failure(let error):
                        #if DEBUG
                        print("FriendsViewModel: Failed to remove friend '\(friendName)': \(error.localizedDescription)")
                        #endif
                        self?.errorMessage = error.localizedDescription
                    }
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

    // MARK: - Family Management

    func addToFamily(_ friendship: Friendship) {
        guard !TutorialManager.shared.isActive else { return }
        guard let userId = currentUserId else { return }
        let friendId = friendship.friendId(currentUserId: userId)
        let friendName = friendship.friendName(currentUserId: userId)

        UserSessionManager.shared.addFamilyMember(friendId) { [weak self] success, error in
            DispatchQueue.main.async {
                if success {
                    self?.successMessage = "\(friendName) added to Family"
                    self?.fetchFriendships()
                } else {
                    self?.errorMessage = error ?? "Failed to add to family"
                }
            }
        }
    }

    func removeFromFamily(_ friendship: Friendship) {
        guard !TutorialManager.shared.isActive else { return }
        guard let userId = currentUserId else { return }
        let friendId = friendship.friendId(currentUserId: userId)
        let friendName = friendship.friendName(currentUserId: userId)

        UserSessionManager.shared.removeFamilyMember(friendId) { [weak self] success, error in
            DispatchQueue.main.async {
                if success {
                    self?.successMessage = "\(friendName) removed from Family"
                    self?.fetchFriendships()
                } else {
                    self?.errorMessage = error ?? "Failed to remove from family"
                }
            }
        }
    }

    func isFamilyMember(_ friendship: Friendship) -> Bool {
        guard let userId = currentUserId else { return false }
        let friendId = friendship.friendId(currentUserId: userId)
        let familyIds = UserSessionManager.shared.currentUser?.familyMemberIds ?? []
        return familyIds.contains(friendId)
    }

    /// Get family members as contacts for sharing
    func getFamilyMembersAsContacts() -> [Contact] {
        guard let userId = currentUserId else { return [] }
        return familyMembers.map { $0.toContact(currentUserId: userId) }
    }

    // MARK: - Helpers

    private func findExistingRelationship(with userId: String) -> Friendship? {
        // Check in all lists (including family members)
        if let existing = familyMembers.first(where: { $0.requesterId == userId || $0.receiverId == userId }) {
            return existing
        }
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

    /// Get accepted friends as contacts for messaging/sharing (includes family members)
    func getAcceptedFriendsAsContacts() -> [Contact] {
        guard let userId = currentUserId else { return [] }
        let allFriends = familyMembers + friends
        return allFriends.map { $0.toContact(currentUserId: userId) }
    }
}
