//
//  MessagesViewModel.swift
//  Geolocation_v1.0.0
//
//  Created by Claude Code
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

class MessagesViewModel: ObservableObject {
    @Published var conversations: [Conversation] = []
    @Published var messages: [Message] = []
    @Published var recentContacts: [Contact] = []
    @Published var searchedContact: Contact?
    @Published var isLoading = false
    @Published var isSearching = false
    @Published var errorMessage: String?
    @Published var totalUnreadCount = 0

    // Pagination state
    @Published var hasMoreMessages = false
    @Published var isLoadingMore = false

    // Profile picture cache for conversation participants
    @Published var participantProfilePictures: [String: String] = [:]
    private var fetchedParticipantIds: Set<String> = []

    private let messagingService = MessagingService.shared
    private var newMessagesListener: ListenerRegistration?
    private var currentConversationId: String?

    // Use the userId from user profile (stored in Firestore), NOT Auth UID
    private var currentUserId: String? {
        UserSessionManager.shared.currentUser?.userId
    }

    deinit {
        stopListeningForMessages()
    }

    // MARK: - Conversations

    func fetchConversations() {
        guard let userId = currentUserId else { return }
        isLoading = true

        messagingService.fetchConversations(for: userId) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                switch result {
                case .success(let conversations):
                    self?.conversations = conversations
                    self?.fetchParticipantProfilePictures(from: conversations)
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                    print("MessagesViewModel: Error fetching conversations: \(error)")
                }
            }
        }
    }

    func fetchUnreadCount() {
        guard let userId = currentUserId else {
            print("⚠️ MessagesViewModel.fetchUnreadCount: No userId available")
            return
        }

        print("📊 MessagesViewModel.fetchUnreadCount: Starting for userId: \(userId)")
        messagingService.getTotalUnreadCount(for: userId) { [weak self] count in
            DispatchQueue.main.async {
                print("📊 MessagesViewModel.fetchUnreadCount: Received count: \(count)")
                self?.totalUnreadCount = count
                print("📊 MessagesViewModel.totalUnreadCount updated to: \(self?.totalUnreadCount ?? -1)")
            }
        }
    }

    /// Delete a conversation and all its messages
    func deleteConversation(_ conversation: Conversation) {
        messagingService.deleteConversation(conversationId: conversation.id) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    // Conversation will be removed automatically via snapshot listener
                    print("MessagesViewModel: Successfully deleted conversation")
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                    print("MessagesViewModel: Error deleting conversation: \(error)")
                }
            }
        }
    }

    // MARK: - Messages

    // Track the oldest timestamp from displayed messages for pagination
    private var oldestDisplayedTimestamp: TimeInterval?
    // Store manually loaded older messages (messages older than what snapshot returns)
    private var olderLoadedMessages: [Message] = []

    /// Fetch paginated messages for a conversation with real-time updates
    func fetchMessages(for conversationId: String) {
        // Clean up previous listener if switching conversations
        if currentConversationId != conversationId {
            stopListeningForMessages()
            messages = []
            hasMoreMessages = false
            oldestDisplayedTimestamp = nil
            olderLoadedMessages = []
        }

        currentConversationId = conversationId
        isLoading = true

        // Use snapshot listener for real-time updates on the most recent messages
        newMessagesListener = messagingService.fetchPaginatedMessages(for: conversationId) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false

                switch result {
                case .success(let (recentMessages, hasMore)):
                    // Merge older loaded messages with recent messages from snapshot
                    // Filter out any duplicates (messages that appear in both)
                    let recentIds = Set(recentMessages.map { $0.id })
                    let uniqueOlderMessages = self.olderLoadedMessages.filter { !recentIds.contains($0.id) }

                    self.messages = uniqueOlderMessages + recentMessages
                    self.hasMoreMessages = hasMore || !uniqueOlderMessages.isEmpty

                    // Track oldest displayed timestamp for pagination
                    if let firstMessage = self.messages.first {
                        self.oldestDisplayedTimestamp = firstMessage.createdAt
                    }

                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                    print("MessagesViewModel: Error fetching messages: \(error)")
                }
            }
        }
    }

    /// Load older messages when user scrolls to top
    func loadMoreMessages() {
        guard let conversationId = currentConversationId,
              hasMoreMessages,
              !isLoadingMore,
              let oldestTimestamp = oldestDisplayedTimestamp else { return }

        isLoadingMore = true

        messagingService.loadOlderMessages(
            for: conversationId,
            beforeTimestamp: oldestTimestamp
        ) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoadingMore = false

                switch result {
                case .success(let (olderMessages, hasMore)):
                    // Store these older messages so they persist across snapshot updates
                    self.olderLoadedMessages = olderMessages + self.olderLoadedMessages
                    // Prepend older messages to the beginning
                    self.messages = olderMessages + self.messages
                    self.hasMoreMessages = hasMore
                    // Update oldest timestamp for next pagination
                    if let firstOldMessage = olderMessages.first {
                        self.oldestDisplayedTimestamp = firstOldMessage.createdAt
                    }

                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                    print("MessagesViewModel: Error loading more messages: \(error)")
                }
            }
        }
    }

    /// Stop listening for messages
    func stopListeningForMessages() {
        newMessagesListener?.remove()
        newMessagesListener = nil
    }

    /// Delete a message
    func deleteMessage(_ message: Message) {
        messagingService.deleteMessage(messageId: message.id) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    // Message will be removed automatically via snapshot listener
                    print("MessagesViewModel: Successfully deleted message")
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                    print("MessagesViewModel: Error deleting message: \(error)")
                }
            }
        }
    }

    func sendMessage(
        conversationId: String,
        content: String,
        linkedReminder: LinkedReminder? = nil,
        senderName: String
    ) {
        guard let userId = currentUserId else { return }

        messagingService.sendMessage(
            conversationId: conversationId,
            senderId: userId,
            senderName: senderName,
            content: content,
            linkedReminder: linkedReminder
        ) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    break // Message will appear via snapshot listener
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                    print("MessagesViewModel: Error sending message: \(error)")
                }
            }
        }
    }

    func markAsRead(conversationId: String) {
        guard let userId = currentUserId else { return }
        messagingService.markMessagesAsRead(conversationId: conversationId, userId: userId)
    }

    // MARK: - Contacts

    func fetchRecentContacts() {
        guard let userId = currentUserId else { return }

        messagingService.getRecentContacts(for: userId) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let contacts):
                    self?.recentContacts = contacts
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                    print("MessagesViewModel: Error fetching contacts: \(error)")
                }
            }
        }
    }

    func searchContact(email: String) {
        guard !email.isEmpty else {
            searchedContact = nil
            return
        }

        isSearching = true
        messagingService.searchUserByEmail(email) { [weak self] result in
            DispatchQueue.main.async {
                self?.isSearching = false
                switch result {
                case .success(let contact):
                    self?.searchedContact = contact
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                    print("MessagesViewModel: Error searching contact: \(error)")
                }
            }
        }
    }

    // MARK: - Create Conversation

    func startConversation(
        with contact: Contact,
        currentUserName: String,
        completion: @escaping (Conversation?) -> Void
    ) {
        guard let userId = currentUserId else {
            completion(nil)
            return
        }

        messagingService.findOrCreateConversation(
            currentUserId: userId,
            currentUserName: currentUserName,
            otherUserId: contact.id,
            otherUserName: contact.name
        ) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let conversation):
                    completion(conversation)
                case .failure(let error):
                    print("MessagesViewModel: Error creating conversation: \(error)")
                    completion(nil)
                }
            }
        }
    }

    // MARK: - Share Reminder

    func shareReminder(
        reminder: Reminder,
        store: Store,
        to contact: Contact,
        currentUserName: String,
        customMessage: String?,
        completion: @escaping (Bool) -> Void
    ) {
        guard let userId = currentUserId else {
            completion(false)
            return
        }

        // First, find or create conversation
        messagingService.findOrCreateConversation(
            currentUserId: userId,
            currentUserName: currentUserName,
            otherUserId: contact.id,
            otherUserName: contact.name
        ) { [weak self] result in
            switch result {
            case .success(let conversation):
                // Now send message with linked reminder including all necessary info for accept/reject
                let linkedReminder = LinkedReminder(
                    reminderTitle: reminder.title,
                    storeName: store.name,
                    storeAddress: nil, // No longer storing addresses
                    reminderId: reminder.id,
                    storeId: store.id,
                    senderUserId: userId,
                    status: .pending,
                    storeLatitude: nil, // No longer storing coordinates
                    storeLongitude: nil,
                    storeImageURL: store.imageURL
                )

                let messageContent = customMessage ?? "Can you pick up \(reminder.title) at \(store.name)?"

                self?.messagingService.sendMessage(
                    conversationId: conversation.id,
                    senderId: userId,
                    senderName: currentUserName,
                    content: messageContent,
                    linkedReminder: linkedReminder
                ) { messageResult in
                    DispatchQueue.main.async {
                        switch messageResult {
                        case .success:
                            completion(true)
                        case .failure(let error):
                            print("MessagesViewModel: Error sending reminder: \(error)")
                            completion(false)
                        }
                    }
                }

            case .failure(let error):
                print("MessagesViewModel: Error creating conversation for reminder: \(error)")
                DispatchQueue.main.async {
                    completion(false)
                }
            }
        }
    }

    // MARK: - Shared Reminder Accept/Reject

    func acceptSharedReminder(
        message: Message,
        completion: @escaping (Bool) -> Void
    ) {
        guard let userId = currentUserId,
              let userEmail = UserSessionManager.shared.currentUser?.email,
              let userName = UserSessionManager.shared.currentUser?.name,
              let linkedReminder = message.linkedReminder else {
            completion(false)
            return
        }

        messagingService.acceptSharedReminder(
            messageId: message.id,
            linkedReminder: linkedReminder,
            currentUserId: userId,
            currentUserEmail: userEmail,
            senderName: message.senderName,
            recipientName: userName
        ) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    print("MessagesViewModel: Successfully accepted shared reminder")
                    completion(true)
                case .failure(let error):
                    print("MessagesViewModel: Error accepting shared reminder: \(error)")
                    completion(false)
                }
            }
        }
    }

    func rejectSharedReminder(
        message: Message,
        completion: @escaping (Bool) -> Void
    ) {
        messagingService.updateLinkedReminderStatus(
            messageId: message.id,
            status: .rejected
        ) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    print("MessagesViewModel: Successfully rejected shared reminder")
                    completion(true)
                case .failure(let error):
                    print("MessagesViewModel: Error rejecting shared reminder: \(error)")
                    completion(false)
                }
            }
        }
    }

    // MARK: - Share Store

    func shareStore(
        userStoreItem: UserStoreItem,
        to contact: Contact,
        permission: String,
        currentUserName: String,
        reminderTitles: [String]?,
        completion: @escaping (Bool) -> Void
    ) {
        print("📤 MessagesViewModel.shareStore: Starting - store=\(userStoreItem.store.name), to=\(contact.name), permission=\(permission)")

        guard let userId = currentUserId else {
            print("📤 MessagesViewModel.shareStore: ERROR - No currentUserId")
            completion(false)
            return
        }

        // Get current user's email for Firestore rule validation when removing access
        let currentUserEmail = UserSessionManager.shared.currentUser?.email

        print("📤 MessagesViewModel.shareStore: Finding or creating conversation...")

        // First, find or create conversation
        messagingService.findOrCreateConversation(
            currentUserId: userId,
            currentUserName: currentUserName,
            otherUserId: contact.id,
            otherUserName: contact.name
        ) { [weak self] result in
            switch result {
            case .success(let conversation):
                print("📤 MessagesViewModel.shareStore: Got conversation \(conversation.id), creating LinkedStore...")

                // Create LinkedStore with all necessary info (no address/coordinates - name-based)
                let linkedStore = LinkedStore(
                    storeName: userStoreItem.store.name,
                    storeAddress: nil, // No longer storing addresses
                    storeId: userStoreItem.store.id,
                    senderUserId: userId,
                    senderUserStoreId: userStoreItem.id,  // Include sender's user_store ID for linking
                    senderEmail: currentUserEmail, // Include for Firestore rule validation
                    status: .pending,
                    permission: permission,
                    storeLatitude: nil, // No longer storing coordinates
                    storeLongitude: nil,
                    storeImageURL: userStoreItem.store.imageURL,
                    reminderTitles: reminderTitles
                )

                let permissionText = permission == "edit" ? "Can Edit" : "View Only"
                let reminderCountText = reminderTitles?.count ?? 0
                let messageContent = "I'd like to share \(userStoreItem.store.name) with you (\(permissionText)). It has \(reminderCountText) reminder(s)."

                print("📤 MessagesViewModel.shareStore: Sending message with linkedStore...")

                self?.messagingService.sendMessage(
                    conversationId: conversation.id,
                    senderId: userId,
                    senderName: currentUserName,
                    content: messageContent,
                    linkedStore: linkedStore
                ) { [weak self] messageResult in
                    switch messageResult {
                    case .success(let message):
                        print("📤 MessagesViewModel.shareStore: SUCCESS - Message sent with id=\(message.id)")

                        // Mark all reminders in this store as shared and update owner's user_store
                        self?.markRemindersAsShared(
                            userStoreItem: userStoreItem,
                            recipientName: contact.name,
                            currentUserName: currentUserName
                        ) {
                            // Also update owner's user_store with sharedWith array
                            self?.updateOwnerStoreSharedWith(
                                userStoreId: userStoreItem.id,
                                recipientName: contact.name
                            ) {
                                DispatchQueue.main.async {
                                    completion(true)
                                }
                            }
                        }

                    case .failure(let error):
                        print("📤 MessagesViewModel.shareStore: ERROR sending message: \(error)")
                        DispatchQueue.main.async {
                            completion(false)
                        }
                    }
                }

            case .failure(let error):
                print("📤 MessagesViewModel.shareStore: ERROR creating conversation: \(error)")
                DispatchQueue.main.async {
                    completion(false)
                }
            }
        }
    }

    /// Mark all reminders in a store as shared
    private func markRemindersAsShared(
        userStoreItem: UserStoreItem,
        recipientName: String,
        currentUserName: String,
        completion: @escaping () -> Void
    ) {
        let db = Firestore.firestore()

        // Determine which ID to use for fetching reminders
        let reminderStoreId = userStoreItem.sourceUserStoreId ?? userStoreItem.sharedStoreGroupId ?? userStoreItem.id

        print("📤 markRemindersAsShared: Marking reminders as shared for storeId=\(reminderStoreId)")

        db.collection("reminders")
            .whereField("userStoreId", isEqualTo: reminderStoreId)
            .whereField("isDone", isEqualTo: false)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("📤 markRemindersAsShared: ERROR fetching reminders - \(error)")
                    completion()
                    return
                }

                guard let documents = snapshot?.documents, !documents.isEmpty else {
                    print("📤 markRemindersAsShared: No reminders to mark")
                    completion()
                    return
                }

                print("📤 markRemindersAsShared: Found \(documents.count) reminders to mark as shared")

                let batch = db.batch()

                for doc in documents {
                    let data = doc.data()
                    var sharedWith = data["sharedWith"] as? [String] ?? []

                    // Only add recipient to sharedWith (not the sender)
                    // The sender is the owner - they see "Shared with [recipient]"
                    // The recipient will see "Shared by [sender]" via sharedFromName on their user_store
                    if !sharedWith.contains(recipientName) {
                        sharedWith.append(recipientName)
                    }

                    batch.updateData([
                        "isShared": true,
                        "sharedWith": sharedWith,
                        "sharedAt": Date().timeIntervalSince1970
                    ], forDocument: doc.reference)
                }

                batch.commit { error in
                    if let error = error {
                        print("📤 markRemindersAsShared: ERROR committing batch - \(error)")
                    } else {
                        print("📤 markRemindersAsShared: SUCCESS - \(documents.count) reminders marked as shared")
                    }
                    completion()
                }
            }
    }

    /// Update the owner's user_store with sharedWith array (for auto-marking new reminders as shared)
    private func updateOwnerStoreSharedWith(
        userStoreId: String,
        recipientName: String,
        completion: @escaping () -> Void
    ) {
        let db = Firestore.firestore()

        print("📤 updateOwnerStoreSharedWith: Updating user_store \(userStoreId) with sharedWith")

        db.collection("user_stores").document(userStoreId).getDocument { snapshot, error in
            if let error = error {
                print("📤 updateOwnerStoreSharedWith: ERROR fetching user_store - \(error)")
                completion()
                return
            }

            guard let data = snapshot?.data() else {
                print("📤 updateOwnerStoreSharedWith: No data found")
                completion()
                return
            }

            var sharedWith = data["sharedWith"] as? [String] ?? []

            // Add recipient if not already in the list
            if !sharedWith.contains(recipientName) {
                sharedWith.append(recipientName)
            }

            db.collection("user_stores").document(userStoreId).updateData([
                "sharedWith": sharedWith,
                "isSharedStore": true
            ]) { error in
                if let error = error {
                    print("📤 updateOwnerStoreSharedWith: ERROR updating - \(error)")
                } else {
                    print("📤 updateOwnerStoreSharedWith: SUCCESS - sharedWith=\(sharedWith)")
                }
                completion()
            }
        }
    }

    // MARK: - Shared Store Accept/Reject

    func acceptSharedStore(
        message: Message,
        completion: @escaping (Bool) -> Void
    ) {
        print("🔵 MessagesViewModel.acceptSharedStore: Starting for message \(message.id)")

        guard let userId = currentUserId else {
            print("🔵 MessagesViewModel.acceptSharedStore: ERROR - No currentUserId")
            completion(false)
            return
        }

        guard let userEmail = UserSessionManager.shared.currentUser?.email else {
            print("🔵 MessagesViewModel.acceptSharedStore: ERROR - No userEmail")
            completion(false)
            return
        }

        guard let linkedStore = message.linkedStore else {
            print("🔵 MessagesViewModel.acceptSharedStore: ERROR - No linkedStore in message")
            completion(false)
            return
        }

        print("🔵 MessagesViewModel.acceptSharedStore: linkedStore=\(linkedStore.storeName), senderUserStoreId=\(linkedStore.senderUserStoreId ?? "nil")")

        messagingService.acceptSharedStore(
            messageId: message.id,
            linkedStore: linkedStore,
            currentUserId: userId,
            currentUserEmail: userEmail,
            senderUserId: linkedStore.senderUserId,
            senderUserStoreId: linkedStore.senderUserStoreId,
            senderName: message.senderName  // Pass sender name for display
        ) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    print("🔵 MessagesViewModel.acceptSharedStore: SUCCESS")
                    completion(true)
                case .failure(let error):
                    print("🔵 MessagesViewModel.acceptSharedStore: FAILURE - \(error)")
                    completion(false)
                }
            }
        }
    }

    func rejectSharedStore(
        message: Message,
        completion: @escaping (Bool) -> Void
    ) {
        messagingService.updateLinkedStoreStatus(
            messageId: message.id,
            status: .rejected
        ) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    print("MessagesViewModel: Successfully rejected shared store")
                    completion(true)
                case .failure(let error):
                    print("MessagesViewModel: Error rejecting shared store: \(error)")
                    completion(false)
                }
            }
        }
    }

    // MARK: - Helpers

    func isCurrentUser(_ senderId: String) -> Bool {
        return senderId == currentUserId
    }

    func clearError() {
        errorMessage = nil
    }

    // MARK: - Profile Pictures

    /// Get the profile picture URL for the other participant in a conversation
    func profilePictureURL(for conversation: Conversation) -> String? {
        guard let userId = currentUserId,
              let otherId = conversation.otherParticipantId(currentUserId: userId) else { return nil }
        return participantProfilePictures[otherId]
    }

    /// Fetch profile picture URLs for conversation participants not yet cached
    private func fetchParticipantProfilePictures(from conversations: [Conversation]) {
        guard let userId = currentUserId else { return }

        // Collect participant IDs we haven't fetched yet
        var needed: Set<String> = []
        for conversation in conversations {
            if let otherId = conversation.otherParticipantId(currentUserId: userId),
               !fetchedParticipantIds.contains(otherId) {
                needed.insert(otherId)
            }
        }

        guard !needed.isEmpty else { return }

        // Firestore 'in' queries limited to 30 items
        let idsArray = Array(needed.prefix(30))

        Firestore.firestore().collection("users")
            .whereField(FieldPath.documentID(), in: idsArray)
            .getDocuments { [weak self] snapshot, error in
                guard let documents = snapshot?.documents else { return }

                DispatchQueue.main.async {
                    for doc in documents {
                        self?.fetchedParticipantIds.insert(doc.documentID)
                        if let url = doc.data()["profilePictureURL"] as? String {
                            self?.participantProfilePictures[doc.documentID] = url
                        }
                    }
                    // Mark IDs that were fetched but had no profile picture
                    for id in idsArray {
                        self?.fetchedParticipantIds.insert(id)
                    }
                }
            }
    }
}
