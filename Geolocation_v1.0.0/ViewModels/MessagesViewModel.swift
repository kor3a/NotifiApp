//
//  MessagesViewModel.swift
//  Geolocation_v1.0.0
//
//  Created by Claude Code
//

import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import UIKit
import Combine

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

    // Draft (unsent) message text per conversation
    var draftMessages: [String: String] = [:]

    private let messagingService = MessagingService.shared
    private var newMessagesListener: ListenerRegistration?
    private var currentConversationId: String?
    private var cancellables = Set<AnyCancellable>()

    // Use the userId from user profile (stored in Firestore), NOT Auth UID
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
                    self?.fetchConversations()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Tutorial Mock Data

    private func loadTutorialMockData() {
        let userId = currentUserId ?? "tutorial_self"
        isLoading = false
        conversations = TutorialMockData.conversations(currentUserId: userId)
        totalUnreadCount = 1
    }

    private func clearTutorialMockData() {
        conversations = []
        totalUnreadCount = 0
    }

    deinit {
        stopListeningForMessages()
    }

    // MARK: - Conversations

    func fetchConversations() {
        guard !TutorialManager.shared.isActive else {
            loadTutorialMockData()
            return
        }
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
                    #if DEBUG
                    print("MessagesViewModel: Error fetching conversations: \(error)")
                    #endif
                }
            }
        }
    }

    func fetchUnreadCount() {
        guard let userId = currentUserId else {
            #if DEBUG
            print("⚠️ MessagesViewModel.fetchUnreadCount: No userId available")
            #endif
            return
        }

        #if DEBUG
        print("📊 MessagesViewModel.fetchUnreadCount: Starting for userId: \(userId)")
        #endif
        messagingService.getTotalUnreadCount(for: userId) { [weak self] count in
            DispatchQueue.main.async {
                #if DEBUG
                print("📊 MessagesViewModel.fetchUnreadCount: Received count: \(count)")
                #endif
                self?.totalUnreadCount = count
                UIApplication.shared.applicationIconBadgeNumber = count
                #if DEBUG
                print("📊 MessagesViewModel.totalUnreadCount updated to: \(self?.totalUnreadCount ?? -1)")
                #endif
            }
        }
    }

    /// Delete a conversation and all its messages
    func deleteConversation(_ conversation: Conversation) {
        guard !TutorialManager.shared.isActive else { return }
        messagingService.deleteConversation(conversationId: conversation.id) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    // Conversation will be removed automatically via snapshot listener
                    #if DEBUG
                    print("MessagesViewModel: Successfully deleted conversation")
                    #endif
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                    #if DEBUG
                    print("MessagesViewModel: Error deleting conversation: \(error)")
                    #endif
                }
            }
        }
    }

    // MARK: - Messages

    // All messages loaded from the snapshot (used for in-memory display windowing)
    private var allLoadedMessages: [Message] = []
    // Number of messages currently shown; increases when user loads earlier messages
    private var displayedCount: Int = MessagingService.messagePageSize

    /// Fetch paginated messages for a conversation with real-time updates
    func fetchMessages(for conversationId: String) {
        // Clean up previous listener if switching conversations
        if currentConversationId != conversationId {
            stopListeningForMessages()
            messages = []
            hasMoreMessages = false
            allLoadedMessages = []
            displayedCount = MessagingService.messagePageSize
        }

        currentConversationId = conversationId
        isLoading = true

        // Use snapshot listener for real-time updates on the most recent messages
        newMessagesListener = messagingService.fetchPaginatedMessages(for: conversationId) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false

                switch result {
                case .success(let (allMessages, _)):
                    // Store the full message list and show only the display window
                    self.allLoadedMessages = allMessages
                    self.messages = Array(allMessages.suffix(self.displayedCount))
                    self.hasMoreMessages = self.displayedCount < allMessages.count

                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                    #if DEBUG
                    print("MessagesViewModel: Error fetching messages: \(error)")
                    #endif
                }
            }
        }
    }

    /// Load older messages when user scrolls to top
    func loadMoreMessages() {
        guard hasMoreMessages, !isLoadingMore else { return }

        // Expand the display window by one page; all data is already in allLoadedMessages
        displayedCount += MessagingService.messagePageSize
        messages = Array(allLoadedMessages.suffix(displayedCount))
        hasMoreMessages = displayedCount < allLoadedMessages.count
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
                    #if DEBUG
                    print("MessagesViewModel: Successfully deleted message")
                    #endif
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                    #if DEBUG
                    print("MessagesViewModel: Error deleting message: \(error)")
                    #endif
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
        guard !TutorialManager.shared.isActive else { return }
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
                    #if DEBUG
                    print("MessagesViewModel: Error sending message: \(error)")
                    #endif
                }
            }
        }
    }

    /// Upload photos to Firebase Storage and send a message with the resulting URLs.
    func sendMessageWithPhotos(
        conversationId: String,
        content: String,
        images: [UIImage],
        senderName: String,
        completion: @escaping (Bool) -> Void
    ) {
        guard !TutorialManager.shared.isActive else { completion(false); return }
        guard let userId = currentUserId else { completion(false); return }

        guard !images.isEmpty else {
            // No images — fall back to plain text message
            sendMessage(conversationId: conversationId, content: content, senderName: senderName)
            completion(true)
            return
        }

        uploadImages(images, conversationId: conversationId) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let urls):
                self.messagingService.sendMessage(
                    conversationId: conversationId,
                    senderId: userId,
                    senderName: senderName,
                    content: content,
                    photoURLs: urls
                ) { messageResult in
                    DispatchQueue.main.async {
                        switch messageResult {
                        case .success:
                            completion(true)
                        case .failure(let error):
                            self.errorMessage = error.localizedDescription
                            #if DEBUG
                            print("MessagesViewModel: Error sending photo message: \(error)")
                            #endif
                            completion(false)
                        }
                    }
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                    #if DEBUG
                    print("MessagesViewModel: Error uploading photos: \(error)")
                    #endif
                    completion(false)
                }
            }
        }
    }

    /// Upload multiple images to Firebase Storage and return their download URLs.
    private func uploadImages(
        _ images: [UIImage],
        conversationId: String,
        completion: @escaping (Result<[String], Error>) -> Void
    ) {
        var uploadedURLs: [String] = []
        var uploadError: Error?
        let group = DispatchGroup()

        for image in images {
            guard let imageData = image.jpegData(compressionQuality: 0.7) else { continue }

            group.enter()
            let photoId = UUID().uuidString
            let photoRef = Storage.storage().reference()
                .child("message_photos/\(conversationId)/\(photoId).jpg")

            let metadata = StorageMetadata()
            metadata.contentType = "image/jpeg"

            photoRef.putData(imageData, metadata: metadata) { _, error in
                if let error = error {
                    uploadError = error
                    group.leave()
                    return
                }
                photoRef.downloadURL { url, error in
                    if let error = error {
                        uploadError = error
                    } else if let url = url {
                        uploadedURLs.append(url.absoluteString)
                    }
                    group.leave()
                }
            }
        }

        group.notify(queue: .main) {
            if let error = uploadError {
                completion(.failure(error))
            } else {
                completion(.success(uploadedURLs))
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
                    #if DEBUG
                    print("MessagesViewModel: Error fetching contacts: \(error)")
                    #endif
                }
            }
        }
    }

    func searchContact(query: String) {
        guard !query.isEmpty else {
            searchedContact = nil
            return
        }

        isSearching = true
        searchedContact = nil

        let handleResult: (Result<Contact?, Error>) -> Void = { [weak self] result in
            DispatchQueue.main.async {
                self?.isSearching = false
                switch result {
                case .success(let contact):
                    self?.searchedContact = contact
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                    #if DEBUG
                    print("MessagesViewModel: Error searching contact: \(error)")
                    #endif
                }
            }
        }

        if query.contains("@") {
            messagingService.searchUserByEmail(query, completion: handleResult)
        } else {
            messagingService.searchUserByUsername(query, completion: handleResult)
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
                    #if DEBUG
                    print("MessagesViewModel: Error creating conversation: \(error)")
                    #endif
                    completion(nil)
                }
            }
        }
    }

    // MARK: - Direct Search (for NewGroupView)

    func messagingServiceSearch(byEmail email: String, completion: @escaping (Result<Contact?, Error>) -> Void) {
        messagingService.searchUserByEmail(email, completion: completion)
    }

    func messagingServiceSearch(byUsername username: String, completion: @escaping (Result<Contact?, Error>) -> Void) {
        messagingService.searchUserByUsername(username, completion: completion)
    }

    // MARK: - Group Conversations

    func createGroupConversation(
        groupName: String,
        members: [Contact],
        completion: @escaping (Conversation?) -> Void
    ) {
        guard let userId = currentUserId,
              let userName = UserSessionManager.shared.currentUser?.name else {
            completion(nil)
            return
        }

        let memberTuples = members.map { (userId: $0.id, name: $0.name) }

        messagingService.createGroupConversation(
            groupName: groupName,
            creatorId: userId,
            creatorName: userName,
            members: memberTuples
        ) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let conversation):
                    completion(conversation)
                case .failure(let error):
                    #if DEBUG
                    print("MessagesViewModel: Error creating group: \(error)")
                    #endif
                    completion(nil)
                }
            }
        }
    }

    func updateGroupName(conversationId: String, newName: String) {
        messagingService.updateGroupName(conversationId: conversationId, newName: newName) { result in
            #if DEBUG
            if case .failure(let error) = result {
                print("MessagesViewModel: Error updating group name: \(error)")
            }
            #endif
        }
    }

    func addGroupMember(conversationId: String, contact: Contact) {
        messagingService.addGroupMember(
            conversationId: conversationId,
            userId: contact.id,
            userName: contact.name
        ) { result in
            #if DEBUG
            if case .failure(let error) = result {
                print("MessagesViewModel: Error adding group member: \(error)")
            }
            #endif
        }
    }

    func leaveGroup(conversationId: String, completion: @escaping (Bool) -> Void) {
        guard let userId = currentUserId else { completion(false); return }
        messagingService.removeGroupMember(conversationId: conversationId, userId: userId) { result in
            DispatchQueue.main.async {
                switch result {
                case .success: completion(true)
                case .failure(let error):
                    #if DEBUG
                    print("MessagesViewModel: Error leaving group: \(error)")
                    #endif
                    completion(false)
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
                            #if DEBUG
                            print("MessagesViewModel: Error sending reminder: \(error)")
                            #endif
                            completion(false)
                        }
                    }
                }

            case .failure(let error):
                #if DEBUG
                print("MessagesViewModel: Error creating conversation for reminder: \(error)")
                #endif
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
            senderUserId: message.senderId,
            senderName: message.senderName,
            recipientName: userName
        ) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    #if DEBUG
                    print("MessagesViewModel: Successfully accepted shared reminder")
                    #endif
                    completion(true)
                case .failure(let error):
                    #if DEBUG
                    print("MessagesViewModel: Error accepting shared reminder: \(error)")
                    #endif
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
                    #if DEBUG
                    print("MessagesViewModel: Successfully rejected shared reminder")
                    #endif
                    completion(true)
                case .failure(let error):
                    #if DEBUG
                    print("MessagesViewModel: Error rejecting shared reminder: \(error)")
                    #endif
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
        #if DEBUG
        print("📤 MessagesViewModel.shareStore: Starting - store=\(userStoreItem.store.name), to=\(contact.name), permission=\(permission)")
        #endif

        guard let userId = currentUserId else {
            #if DEBUG
            print("📤 MessagesViewModel.shareStore: ERROR - No currentUserId")
            #endif
            completion(false)
            return
        }

        // Get current user's email for Firestore rule validation when removing access
        let currentUserEmail = UserSessionManager.shared.currentUser?.email

        #if DEBUG
        print("📤 MessagesViewModel.shareStore: Finding or creating conversation...")
        #endif

        // First, find or create conversation
        messagingService.findOrCreateConversation(
            currentUserId: userId,
            currentUserName: currentUserName,
            otherUserId: contact.id,
            otherUserName: contact.name
        ) { [weak self] result in
            switch result {
            case .success(let conversation):
                #if DEBUG
                print("📤 MessagesViewModel.shareStore: Got conversation \(conversation.id), creating LinkedStore...")
                #endif

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

                #if DEBUG
                print("📤 MessagesViewModel.shareStore: Sending message with linkedStore...")
                #endif

                self?.messagingService.sendMessage(
                    conversationId: conversation.id,
                    senderId: userId,
                    senderName: currentUserName,
                    content: messageContent,
                    linkedStore: linkedStore
                ) { [weak self] messageResult in
                    switch messageResult {
                    case .success(let message):
                        #if DEBUG
                        print("📤 MessagesViewModel.shareStore: SUCCESS - Message sent with id=\(message.id)")
                        #endif

                        // Mark all reminders in this store as shared
                        // Note: owner's user_store sharedWith is updated when recipient accepts the invite
                        self?.markRemindersAsShared(
                            userStoreItem: userStoreItem,
                            recipientName: contact.name,
                            currentUserName: currentUserName
                        ) {
                            DispatchQueue.main.async {
                                completion(true)
                            }
                        }

                    case .failure(let error):
                        #if DEBUG
                        print("📤 MessagesViewModel.shareStore: ERROR sending message: \(error)")
                        #endif
                        DispatchQueue.main.async {
                            completion(false)
                        }
                    }
                }

            case .failure(let error):
                #if DEBUG
                print("📤 MessagesViewModel.shareStore: ERROR creating conversation: \(error)")
                #endif
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

        #if DEBUG
        print("📤 markRemindersAsShared: Marking reminders as shared for storeId=\(reminderStoreId)")
        #endif

        db.collection("reminders")
            .whereField("userStoreId", isEqualTo: reminderStoreId)
            .whereField("isDone", isEqualTo: false)
            .getDocuments { snapshot, error in
                if let error = error {
                    #if DEBUG
                    print("📤 markRemindersAsShared: ERROR fetching reminders - \(error)")
                    #endif
                    completion()
                    return
                }

                guard let documents = snapshot?.documents, !documents.isEmpty else {
                    #if DEBUG
                    print("📤 markRemindersAsShared: No reminders to mark")
                    #endif
                    completion()
                    return
                }

                #if DEBUG
                print("📤 markRemindersAsShared: Found \(documents.count) reminders to mark as shared")
                #endif

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
                    #if DEBUG
                    if let error = error {
                        print("📤 markRemindersAsShared: ERROR committing batch - \(error)")
                    } else {
                        print("📤 markRemindersAsShared: SUCCESS - \(documents.count) reminders marked as shared")
                    }
                    #endif
                    completion()
                }
            }
    }

    // MARK: - Shared Store Accept/Reject

    /// Checks whether the current user already has a store with the given storeId.
    func checkIfUserHasStore(storeId: String, completion: @escaping (Bool) -> Void) {
        guard let userId = currentUserId else {
            completion(false)
            return
        }
        Firestore.firestore().collection("user_stores")
            .whereField("userId", isEqualTo: userId)
            .whereField("storeId", isEqualTo: storeId)
            .getDocuments { snapshot, _ in
                DispatchQueue.main.async {
                    completion(snapshot?.documents.isEmpty == false)
                }
            }
    }

    func acceptSharedStore(
        message: Message,
        completion: @escaping (Bool) -> Void
    ) {
        #if DEBUG
        print("🔵 MessagesViewModel.acceptSharedStore: Starting for message \(message.id)")
        #endif

        guard let userId = currentUserId else {
            #if DEBUG
            print("🔵 MessagesViewModel.acceptSharedStore: ERROR - No currentUserId")
            #endif
            completion(false)
            return
        }

        guard let userEmail = UserSessionManager.shared.currentUser?.email else {
            #if DEBUG
            print("🔵 MessagesViewModel.acceptSharedStore: ERROR - No userEmail")
            #endif
            completion(false)
            return
        }

        guard let userName = UserSessionManager.shared.currentUser?.name else {
            #if DEBUG
            print("🔵 MessagesViewModel.acceptSharedStore: ERROR - No userName")
            #endif
            completion(false)
            return
        }

        guard let linkedStore = message.linkedStore else {
            #if DEBUG
            print("🔵 MessagesViewModel.acceptSharedStore: ERROR - No linkedStore in message")
            #endif
            completion(false)
            return
        }

        #if DEBUG
        print("🔵 MessagesViewModel.acceptSharedStore: linkedStore=\(linkedStore.storeName), senderUserStoreId=\(linkedStore.senderUserStoreId ?? "nil")")
        #endif

        messagingService.acceptSharedStore(
            messageId: message.id,
            linkedStore: linkedStore,
            currentUserId: userId,
            currentUserEmail: userEmail,
            senderUserId: linkedStore.senderUserId,
            senderUserStoreId: linkedStore.senderUserStoreId,
            senderName: message.senderName,  // Pass sender name for display
            recipientName: userName  // Pass recipient name to update owner's sharedWith
        ) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    #if DEBUG
                    print("🔵 MessagesViewModel.acceptSharedStore: SUCCESS")
                    #endif
                    completion(true)
                case .failure(let error):
                    #if DEBUG
                    print("🔵 MessagesViewModel.acceptSharedStore: FAILURE - \(error)")
                    #endif
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
                    #if DEBUG
                    print("MessagesViewModel: Successfully rejected shared store")
                    #endif
                    completion(true)
                case .failure(let error):
                    #if DEBUG
                    print("MessagesViewModel: Error rejecting shared store: \(error)")
                    #endif
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

    /// Get the profile picture URL for the other participant in a 1:1 conversation
    func profilePictureURL(for conversation: Conversation) -> String? {
        guard let userId = currentUserId,
              let otherId = conversation.otherParticipantId(currentUserId: userId) else { return nil }
        return participantProfilePictures[otherId]
    }

    /// Get profile picture URLs for all members of a group (excluding current user)
    func groupMemberProfilePictures(for conversation: Conversation) -> [String: String] {
        guard let userId = currentUserId else { return [:] }
        let otherIds = conversation.otherParticipantIds(currentUserId: userId)
        return otherIds.reduce(into: [:]) { result, id in
            result[id] = participantProfilePictures[id]
        }
    }

    /// Fetch profile picture URLs for conversation participants not yet cached
    private func fetchParticipantProfilePictures(from conversations: [Conversation]) {
        guard let userId = currentUserId else { return }

        // Collect participant IDs we haven't fetched yet (handles both 1:1 and groups)
        // Include ALL participant IDs — the current user is shown in GroupInfoView too
        var needed: Set<String> = []
        for conversation in conversations {
            for participantId in conversation.participantIds where !fetchedParticipantIds.contains(participantId) {
                needed.insert(participantId)
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
