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

    private let messagingService = MessagingService.shared
    private var newMessagesListener: ListenerRegistration?
    private var currentConversationId: String?

    // Use the userId from user profile (stored in Firestore), NOT Auth UID
    private var currentUserId: String? {
        UserSessionManager.shared.currentUser?.userId
    }

    deinit {
        stopListeningForNewMessages()
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

    // MARK: - Messages

    /// Fetch initial paginated messages for a conversation
    func fetchMessages(for conversationId: String) {
        // Clean up previous listener if switching conversations
        if currentConversationId != conversationId {
            stopListeningForNewMessages()
            messages = []
            hasMoreMessages = false
        }

        currentConversationId = conversationId
        isLoading = true

        messagingService.fetchInitialMessages(for: conversationId) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false

                switch result {
                case .success(let (fetchedMessages, hasMore)):
                    self.messages = fetchedMessages
                    self.hasMoreMessages = hasMore

                    // Start listening for new messages after the most recent one
                    self.startListeningForNewMessages(conversationId: conversationId)

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
              let oldestMessage = messages.first else { return }

        isLoadingMore = true

        messagingService.loadOlderMessages(
            for: conversationId,
            beforeTimestamp: oldestMessage.createdAt
        ) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoadingMore = false

                switch result {
                case .success(let (olderMessages, hasMore)):
                    // Prepend older messages to the beginning
                    self.messages = olderMessages + self.messages
                    self.hasMoreMessages = hasMore

                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                    print("MessagesViewModel: Error loading more messages: \(error)")
                }
            }
        }
    }

    /// Start listening for new messages in real-time
    private func startListeningForNewMessages(conversationId: String) {
        // Use the most recent message timestamp, or current time if no messages
        let afterTimestamp = messages.last?.createdAt ?? Date().timeIntervalSince1970

        newMessagesListener = messagingService.listenForNewMessages(
            for: conversationId,
            afterTimestamp: afterTimestamp
        ) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }

                switch result {
                case .success(let newMessages):
                    // Add only messages that aren't already in our list
                    let existingIds = Set(self.messages.map { $0.id })
                    let uniqueNewMessages = newMessages.filter { !existingIds.contains($0.id) }

                    if !uniqueNewMessages.isEmpty {
                        self.messages.append(contentsOf: uniqueNewMessages)
                    }

                case .failure(let error):
                    print("MessagesViewModel: Error listening for new messages: \(error)")
                }
            }
        }
    }

    /// Stop listening for new messages
    func stopListeningForNewMessages() {
        newMessagesListener?.remove()
        newMessagesListener = nil
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
                    storeAddress: store.address,
                    reminderId: reminder.id,
                    storeId: store.id,
                    senderUserId: userId,
                    status: .pending,
                    storeLatitude: store.latitude,
                    storeLongitude: store.longitude,
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

    // MARK: - Helpers

    func isCurrentUser(_ senderId: String) -> Bool {
        return senderId == currentUserId
    }

    func clearError() {
        errorMessage = nil
    }
}
