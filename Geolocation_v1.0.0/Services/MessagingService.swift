//
//  MessagingService.swift
//  Geolocation_v1.0.0
//
//  Created by Claude Code
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

class MessagingService: ObservableObject {
    static let shared = MessagingService()

    private let db = Firestore.firestore()

    // Track incoming message listener
    private var incomingMessageListener: ListenerRegistration?
    private var listenerStartTime: TimeInterval = 0
    private var notifiedMessageIds: Set<String> = []

    private init() {}

    // MARK: - Conversations

    /// Fetch all conversations for the current user
    func fetchConversations(for userId: String, completion: @escaping (Result<[Conversation], Error>) -> Void) {
        db.collection("conversations")
            .whereField("participantIds", arrayContains: userId)
            .order(by: "lastMessageAt", descending: true)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }

                guard let documents = snapshot?.documents else {
                    completion(.success([]))
                    return
                }

                let conversations = documents.compactMap { doc -> Conversation? in
                    return self.parseConversation(from: doc)
                }

                completion(.success(conversations))
            }
    }

    /// Find or create a conversation between two users
    func findOrCreateConversation(
        currentUserId: String,
        currentUserName: String,
        otherUserId: String,
        otherUserName: String,
        completion: @escaping (Result<Conversation, Error>) -> Void
    ) {
        // First, try to find existing conversation
        db.collection("conversations")
            .whereField("participantIds", arrayContains: currentUserId)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }

                if let error = error {
                    completion(.failure(error))
                    return
                }

                // Look for conversation with both participants
                if let existingDoc = snapshot?.documents.first(where: { doc in
                    guard let participantIds = doc.data()["participantIds"] as? [String] else { return false }
                    return participantIds.contains(otherUserId)
                }) {
                    if let conversation = self.parseConversation(from: existingDoc) {
                        completion(.success(conversation))
                        return
                    }
                }

                // Create new conversation
                self.createConversation(
                    currentUserId: currentUserId,
                    currentUserName: currentUserName,
                    otherUserId: otherUserId,
                    otherUserName: otherUserName,
                    completion: completion
                )
            }
    }

    private func createConversation(
        currentUserId: String,
        currentUserName: String,
        otherUserId: String,
        otherUserName: String,
        completion: @escaping (Result<Conversation, Error>) -> Void
    ) {
        let now = Date().timeIntervalSince1970
        let conversationData: [String: Any] = [
            "participantIds": [currentUserId, otherUserId],
            "participantNames": [currentUserId: currentUserName, otherUserId: otherUserName],
            "createdAt": now,
            "lastMessageContent": "",
            "lastMessageAt": now,  // Use creation time so it appears in ordered queries
            "lastMessageSenderId": "",
            "unreadCount": [currentUserId: 0, otherUserId: 0]
        ]

        var ref: DocumentReference?
        ref = db.collection("conversations").addDocument(data: conversationData) { error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let docId = ref?.documentID else {
                completion(.failure(NSError(domain: "MessagingService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create conversation"])))
                return
            }

            let conversation = Conversation(
                id: docId,
                participantIds: [currentUserId, otherUserId],
                participantNames: [currentUserId: currentUserName, otherUserId: otherUserName],
                createdAt: now,
                lastMessageContent: "",
                lastMessageAt: now,
                lastMessageSenderId: "",
                unreadCount: [currentUserId: 0, otherUserId: 0]
            )

            completion(.success(conversation))
        }
    }

    // MARK: - Messages

    /// Default page size for message pagination
    static let messagePageSize = 25

    /// Fetch messages for a conversation (legacy - loads all messages)
    func fetchMessages(for conversationId: String, completion: @escaping (Result<[Message], Error>) -> Void) {
        db.collection("messages")
            .whereField("conversationId", isEqualTo: conversationId)
            .order(by: "createdAt", descending: false)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }

                guard let documents = snapshot?.documents else {
                    completion(.success([]))
                    return
                }

                let messages = documents.compactMap { doc -> Message? in
                    return self.parseMessage(from: doc)
                }

                completion(.success(messages))
            }
    }

    /// Fetch paginated messages for a conversation with real-time updates
    /// Returns a listener that provides messages sorted oldest to newest for display
    func fetchPaginatedMessages(
        for conversationId: String,
        limit: Int = MessagingService.messagePageSize,
        completion: @escaping (Result<(messages: [Message], hasMore: Bool), Error>) -> Void
    ) -> ListenerRegistration {
        // Use snapshot listener with ascending order for reliable real-time updates
        // The limit is applied in the result processing to show only recent messages
        return db.collection("messages")
            .whereField("conversationId", isEqualTo: conversationId)
            .order(by: "createdAt", descending: false)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }

                if let error = error {
                    #if DEBUG
                    print("MessagingService: Error fetching paginated messages: \(error)")
                    #endif
                    completion(.failure(error))
                    return
                }

                guard let documents = snapshot?.documents else {
                    completion(.success((messages: [], hasMore: false)))
                    return
                }

                // Parse all messages (already in oldest-first order)
                let allMessages = documents.compactMap { self.parseMessage(from: $0) }

                // Check if there are more messages than our display limit
                let hasMore = allMessages.count > limit

                // Only return the most recent messages (last N)
                let messages = hasMore ? Array(allMessages.suffix(limit)) : allMessages

                completion(.success((messages: messages, hasMore: hasMore)))
            }
    }

    /// Load older messages before a given timestamp (one-time fetch)
    func loadOlderMessages(
        for conversationId: String,
        beforeTimestamp: TimeInterval,
        limit: Int = MessagingService.messagePageSize,
        completion: @escaping (Result<(messages: [Message], hasMore: Bool), Error>) -> Void
    ) {
        // Fetch limit + 1 to determine if there are more older messages
        db.collection("messages")
            .whereField("conversationId", isEqualTo: conversationId)
            .whereField("createdAt", isLessThan: beforeTimestamp)
            .order(by: "createdAt", descending: true)
            .limit(to: limit + 1)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }

                if let error = error {
                    #if DEBUG
                    print("MessagingService: Error loading older messages: \(error)")
                    #endif
                    completion(.failure(error))
                    return
                }

                guard let documents = snapshot?.documents else {
                    completion(.success((messages: [], hasMore: false)))
                    return
                }

                // Check if there are more messages beyond our limit
                let hasMore = documents.count > limit
                let docsToProcess = hasMore ? Array(documents.prefix(limit)) : documents

                // Parse and reverse to get oldest-first order for display
                let messages = docsToProcess.compactMap { self.parseMessage(from: $0) }.reversed()

                completion(.success((messages: Array(messages), hasMore: hasMore)))
            }
    }

    /// Delete a message
    func deleteMessage(messageId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        db.collection("messages").document(messageId).delete { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }

    /// Delete a conversation and all its messages
    func deleteConversation(conversationId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        // First delete all messages in the conversation
        db.collection("messages")
            .whereField("conversationId", isEqualTo: conversationId)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }

                if let error = error {
                    completion(.failure(error))
                    return
                }

                let batch = self.db.batch()

                // Add all messages to batch delete
                snapshot?.documents.forEach { doc in
                    batch.deleteDocument(doc.reference)
                }

                // Add the conversation document to batch delete
                let conversationRef = self.db.collection("conversations").document(conversationId)
                batch.deleteDocument(conversationRef)

                // Commit the batch
                batch.commit { error in
                    if let error = error {
                        completion(.failure(error))
                    } else {
                        completion(.success(()))
                    }
                }
            }
    }

    /// Send a message
    func sendMessage(
        conversationId: String,
        senderId: String,
        senderName: String,
        content: String,
        linkedReminder: LinkedReminder? = nil,
        linkedStore: LinkedStore? = nil,
        completion: @escaping (Result<Message, Error>) -> Void
    ) {
        let now = Date().timeIntervalSince1970

        var messageData: [String: Any] = [
            "conversationId": conversationId,
            "senderId": senderId,
            "senderName": senderName,
            "content": content,
            "createdAt": now,
            "isRead": false
        ]

        if let reminder = linkedReminder {
            var reminderData: [String: Any] = [
                "reminderTitle": reminder.reminderTitle,
                "storeName": reminder.storeName
            ]
            if let address = reminder.storeAddress {
                reminderData["storeAddress"] = address
            }
            if let reminderId = reminder.reminderId {
                reminderData["reminderId"] = reminderId
            }
            if let storeId = reminder.storeId {
                reminderData["storeId"] = storeId
            }
            if let senderUserId = reminder.senderUserId {
                reminderData["senderUserId"] = senderUserId
            }
            if let status = reminder.status {
                reminderData["status"] = status.rawValue
            }
            if let latitude = reminder.storeLatitude {
                reminderData["storeLatitude"] = latitude
            }
            if let longitude = reminder.storeLongitude {
                reminderData["storeLongitude"] = longitude
            }
            if let imageURL = reminder.storeImageURL {
                reminderData["storeImageURL"] = imageURL
            }
            messageData["linkedReminder"] = reminderData
        }

        if let store = linkedStore {
            var storeData: [String: Any] = [
                "storeName": store.storeName,
                "storeId": store.storeId,
                "senderUserId": store.senderUserId,
                "permission": store.permission
            ]
            if let address = store.storeAddress {
                storeData["storeAddress"] = address
            }
            if let senderUserStoreId = store.senderUserStoreId {
                storeData["senderUserStoreId"] = senderUserStoreId
            }
            if let status = store.status {
                storeData["status"] = status.rawValue
            }
            if let latitude = store.storeLatitude {
                storeData["storeLatitude"] = latitude
            }
            if let longitude = store.storeLongitude {
                storeData["storeLongitude"] = longitude
            }
            if let imageURL = store.storeImageURL {
                storeData["storeImageURL"] = imageURL
            }
            if let reminderTitles = store.reminderTitles, !reminderTitles.isEmpty {
                storeData["reminderTitles"] = reminderTitles
            }
            messageData["linkedStore"] = storeData
        }

        var ref: DocumentReference?
        ref = db.collection("messages").addDocument(data: messageData) { [weak self] error in
            guard let self = self else { return }

            if let error = error {
                completion(.failure(error))
                return
            }

            guard let docId = ref?.documentID else {
                completion(.failure(NSError(domain: "MessagingService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create message"])))
                return
            }

            // Update conversation with last message info
            self.updateConversationLastMessage(
                conversationId: conversationId,
                senderId: senderId,
                content: content,
                timestamp: now
            )

            let message = Message(
                id: docId,
                conversationId: conversationId,
                senderId: senderId,
                senderName: senderName,
                content: content,
                createdAt: now,
                isRead: false,
                linkedReminder: linkedReminder,
                linkedStore: linkedStore
            )

            completion(.success(message))
        }
    }

    /// Update conversation with last message info and increment unread count
    private func updateConversationLastMessage(
        conversationId: String,
        senderId: String,
        content: String,
        timestamp: TimeInterval
    ) {
        let conversationRef = db.collection("conversations").document(conversationId)

        // Get the conversation to find other participant
        conversationRef.getDocument { snapshot, error in
            guard let data = snapshot?.data(),
                  let participantIds = data["participantIds"] as? [String] else { return }

            // Find the other participant to increment their unread count
            var unreadCount = data["unreadCount"] as? [String: Int] ?? [:]
            for participantId in participantIds {
                if participantId != senderId {
                    unreadCount[participantId] = (unreadCount[participantId] ?? 0) + 1
                }
            }

            conversationRef.updateData([
                "lastMessageContent": content,
                "lastMessageAt": timestamp,
                "lastMessageSenderId": senderId,
                "unreadCount": unreadCount
            ])
        }
    }

    /// Mark messages as read
    func markMessagesAsRead(conversationId: String, userId: String) {
        // Update all unread messages in conversation
        db.collection("messages")
            .whereField("conversationId", isEqualTo: conversationId)
            .whereField("isRead", isEqualTo: false)
            .whereField("senderId", isNotEqualTo: userId)
            .getDocuments { [weak self] snapshot, error in
                guard let documents = snapshot?.documents else { return }

                let batch = self?.db.batch()
                for doc in documents {
                    batch?.updateData(["isRead": true], forDocument: doc.reference)
                }
                batch?.commit(completion: nil)
            }

        // Reset unread count for this user
        db.collection("conversations").document(conversationId).updateData([
            "unreadCount.\(userId)": 0
        ])
    }

    /// Set a message attribute (for SiriKit INSetMessageAttributeIntent)
    func setMessageAttribute(messageId: String, isRead: Bool, completion: @escaping (Result<Void, Error>) -> Void) {
        db.collection("messages").document(messageId).updateData([
            "isRead": isRead
        ]) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }

    // MARK: - Search Messages (for SiriKit INSearchForMessagesIntent)

    /// Search for messages matching criteria
    func searchMessages(
        userId: String,
        searchText: String? = nil,
        fromSenderId: String? = nil,
        limit: Int = 20,
        completion: @escaping (Result<[Message], Error>) -> Void
    ) {
        // First get user's conversations
        db.collection("conversations")
            .whereField("participantIds", arrayContains: userId)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }

                if let error = error {
                    completion(.failure(error))
                    return
                }

                let conversationIds = snapshot?.documents.map { $0.documentID } ?? []
                guard !conversationIds.isEmpty else {
                    completion(.success([]))
                    return
                }

                // Fetch messages from these conversations
                var query: Query = self.db.collection("messages")
                    .whereField("conversationId", in: conversationIds)
                    .order(by: "createdAt", descending: true)
                    .limit(to: limit)

                if let senderId = fromSenderId {
                    query = query.whereField("senderId", isEqualTo: senderId)
                }

                query.getDocuments { snapshot, error in
                    if let error = error {
                        completion(.failure(error))
                        return
                    }

                    var messages = snapshot?.documents.compactMap { self.parseMessage(from: $0) } ?? []

                    // Filter by search text if provided (client-side filtering)
                    if let searchText = searchText?.lowercased(), !searchText.isEmpty {
                        messages = messages.filter {
                            $0.content.lowercased().contains(searchText) ||
                            $0.senderName.lowercased().contains(searchText)
                        }
                    }

                    completion(.success(messages))
                }
            }
    }

    // MARK: - Contacts

    /// Search for users by email to add as contacts
    func searchUserByEmail(_ email: String, completion: @escaping (Result<Contact?, Error>) -> Void) {
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

                // Use userId field if available, otherwise fall back to document ID
                let userId = data["userId"] as? String ?? doc.documentID

                let contact = Contact(
                    id: userId,
                    name: name,
                    email: email,
                    profilePictureURL: data["profilePictureURL"] as? String
                )

                completion(.success(contact))
            }
    }

    /// Get user's recent contacts (people they've messaged)
    func getRecentContacts(for userId: String, completion: @escaping (Result<[Contact], Error>) -> Void) {
        db.collection("conversations")
            .whereField("participantIds", arrayContains: userId)
            .order(by: "lastMessageAt", descending: true)
            .limit(to: 20)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }

                if let error = error {
                    completion(.failure(error))
                    return
                }

                guard let documents = snapshot?.documents else {
                    completion(.success([]))
                    return
                }

                var contactIds: [String] = []
                var contactNames: [String: String] = [:]

                for doc in documents {
                    let data = doc.data()
                    guard let participantIds = data["participantIds"] as? [String],
                          let participantNames = data["participantNames"] as? [String: String] else { continue }

                    for participantId in participantIds where participantId != userId {
                        if !contactIds.contains(participantId) {
                            contactIds.append(participantId)
                            contactNames[participantId] = participantNames[participantId] ?? "Unknown"
                        }
                    }
                }

                // Fetch full contact info
                self.fetchContactDetails(contactIds: contactIds, fallbackNames: contactNames, completion: completion)
            }
    }

    private func fetchContactDetails(contactIds: [String], fallbackNames: [String: String], completion: @escaping (Result<[Contact], Error>) -> Void) {
        guard !contactIds.isEmpty else {
            completion(.success([]))
            return
        }

        db.collection("users")
            .whereField(FieldPath.documentID(), in: contactIds)
            .getDocuments { snapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }

                let contacts = contactIds.compactMap { contactId -> Contact? in
                    if let doc = snapshot?.documents.first(where: { $0.documentID == contactId }) {
                        let data = doc.data()
                        return Contact(
                            id: doc.documentID,
                            name: data["name"] as? String ?? fallbackNames[contactId] ?? "Unknown",
                            email: data["email"] as? String ?? "",
                            profilePictureURL: data["profilePictureURL"] as? String
                        )
                    } else {
                        return Contact(
                            id: contactId,
                            name: fallbackNames[contactId] ?? "Unknown",
                            email: "",
                            profilePictureURL: nil
                        )
                    }
                }

                completion(.success(contacts))
            }
    }

    // MARK: - Parsing Helpers

    private func parseConversation(from doc: QueryDocumentSnapshot) -> Conversation? {
        let data = doc.data()

        guard let participantIds = data["participantIds"] as? [String],
              let participantNames = data["participantNames"] as? [String: String],
              let createdAt = data["createdAt"] as? TimeInterval else {
            return nil
        }

        return Conversation(
            id: doc.documentID,
            participantIds: participantIds,
            participantNames: participantNames,
            createdAt: createdAt,
            lastMessageContent: data["lastMessageContent"] as? String,
            lastMessageAt: data["lastMessageAt"] as? TimeInterval,
            lastMessageSenderId: data["lastMessageSenderId"] as? String,
            unreadCount: data["unreadCount"] as? [String: Int] ?? [:]
        )
    }

    private func parseMessage(from doc: QueryDocumentSnapshot) -> Message? {
        let data = doc.data()

        guard let conversationId = data["conversationId"] as? String,
              let senderId = data["senderId"] as? String,
              let senderName = data["senderName"] as? String,
              let content = data["content"] as? String,
              let createdAt = data["createdAt"] as? TimeInterval else {
            return nil
        }

        var linkedReminder: LinkedReminder?
        if let reminderData = data["linkedReminder"] as? [String: Any],
           let reminderTitle = reminderData["reminderTitle"] as? String,
           let storeName = reminderData["storeName"] as? String {
            var status: SharedReminderStatus? = nil
            if let statusString = reminderData["status"] as? String {
                status = SharedReminderStatus(rawValue: statusString)
            }
            linkedReminder = LinkedReminder(
                reminderTitle: reminderTitle,
                storeName: storeName,
                storeAddress: reminderData["storeAddress"] as? String,
                reminderId: reminderData["reminderId"] as? String,
                storeId: reminderData["storeId"] as? String,
                senderUserId: reminderData["senderUserId"] as? String,
                status: status,
                storeLatitude: reminderData["storeLatitude"] as? Double,
                storeLongitude: reminderData["storeLongitude"] as? Double,
                storeImageURL: reminderData["storeImageURL"] as? String
            )
        }

        var linkedStore: LinkedStore?
        if let storeData = data["linkedStore"] as? [String: Any],
           let storeName = storeData["storeName"] as? String,
           let storeId = storeData["storeId"] as? String,
           let senderUserId = storeData["senderUserId"] as? String {
            var status: SharedReminderStatus? = nil
            if let statusString = storeData["status"] as? String {
                status = SharedReminderStatus(rawValue: statusString)
            }
            linkedStore = LinkedStore(
                storeName: storeName,
                storeAddress: storeData["storeAddress"] as? String,
                storeId: storeId,
                senderUserId: senderUserId,
                senderUserStoreId: storeData["senderUserStoreId"] as? String,
                senderEmail: storeData["senderEmail"] as? String,
                status: status,
                permission: storeData["permission"] as? String ?? "edit",
                storeLatitude: storeData["storeLatitude"] as? Double,
                storeLongitude: storeData["storeLongitude"] as? Double,
                storeImageURL: storeData["storeImageURL"] as? String,
                reminderTitles: storeData["reminderTitles"] as? [String]
            )
        }

        return Message(
            id: doc.documentID,
            conversationId: conversationId,
            senderId: senderId,
            senderName: senderName,
            content: content,
            createdAt: createdAt,
            isRead: data["isRead"] as? Bool ?? false,
            linkedReminder: linkedReminder,
            linkedStore: linkedStore
        )
    }

    // MARK: - Total Unread Count

    /// Get total unread message count for badge
    func getTotalUnreadCount(for userId: String, completion: @escaping (Int) -> Void) {
        #if DEBUG
        print("📊 MessagingService.getTotalUnreadCount: Setting up listener for userId: \(userId)")
        #endif
        db.collection("conversations")
            .whereField("participantIds", arrayContains: userId)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    #if DEBUG
                    print("❌ MessagingService.getTotalUnreadCount: Error: \(error.localizedDescription)")
                    #endif
                    completion(0)
                    return
                }

                guard let documents = snapshot?.documents else {
                    #if DEBUG
                    print("📊 MessagingService.getTotalUnreadCount: No documents found")
                    #endif
                    completion(0)
                    return
                }

                #if DEBUG
                print("📊 MessagingService.getTotalUnreadCount: Found \(documents.count) conversations")
                #endif
                var totalUnread = 0
                for doc in documents {
                    let data = doc.data()
                    if let unreadCount = data["unreadCount"] as? [String: Int] {
                        let count = unreadCount[userId] ?? 0
                        #if DEBUG
                        print("   - Conversation \(doc.documentID): unread count = \(count)")
                        #endif
                        totalUnread += count
                    } else {
                        #if DEBUG
                        print("   - Conversation \(doc.documentID): no unreadCount field")
                        #endif
                    }
                }

                #if DEBUG
                print("📊 MessagingService.getTotalUnreadCount: Total unread = \(totalUnread)")
                #endif
                completion(totalUnread)
            }
    }

    // MARK: - Shared Reminder Accept/Reject

    /// Update the status of a linked reminder in a message
    func updateLinkedReminderStatus(messageId: String, status: SharedReminderStatus, completion: @escaping (Result<Void, Error>) -> Void) {
        db.collection("messages").document(messageId).updateData([
            "linkedReminder.status": status.rawValue
        ]) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }

    /// Update the status of a linked store in a message
    func updateLinkedStoreStatus(messageId: String, status: SharedReminderStatus, completion: @escaping (Result<Void, Error>) -> Void) {
        db.collection("messages").document(messageId).updateData([
            "linkedStore.status": status.rawValue
        ]) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }

    // MARK: - Shared Store Accept/Reject

    /// Accept a shared store - adds the store to the user's list with appropriate permission
    func acceptSharedStore(
        messageId: String,
        linkedStore: LinkedStore,
        currentUserId: String,
        currentUserEmail: String,
        senderUserId: String,
        senderUserStoreId: String?,
        senderName: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        #if DEBUG
        print("🟢 MessagingService.acceptSharedStore: Starting for store '\(linkedStore.storeName)'")
        print("🟢 MessagingService.acceptSharedStore: messageId=\(messageId), currentUserId=\(currentUserId)")
        print("🟢 MessagingService.acceptSharedStore: senderUserStoreId=\(senderUserStoreId ?? "nil"), permission=\(linkedStore.permission)")
        #endif

        // Check if user already has this store
        db.collection("user_stores")
            .whereField("userId", isEqualTo: currentUserId)
            .whereField("storeId", isEqualTo: linkedStore.storeId)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else {
                    #if DEBUG
                    print("🟢 MessagingService.acceptSharedStore: ERROR - self is nil")
                    #endif
                    return
                }

                if let error = error {
                    #if DEBUG
                    print("🟢 MessagingService.acceptSharedStore: ERROR checking existing store - \(error)")
                    #endif
                    completion(.failure(error))
                    return
                }

                #if DEBUG
                print("🟢 MessagingService.acceptSharedStore: Existing stores check - found \(snapshot?.documents.count ?? 0) documents")
                #endif

                if snapshot?.documents.isEmpty == false {
                    // User already has this store, just update status
                    #if DEBUG
                    print("🟢 MessagingService.acceptSharedStore: User already has store, marking as accepted")
                    #endif
                    self.updateLinkedStoreStatus(messageId: messageId, status: .accepted, completion: completion)
                    return
                }

                #if DEBUG
                print("🟢 MessagingService.acceptSharedStore: Getting store count for sortOrder...")
                #endif

                // Get user's current store count for sortOrder
                self.db.collection("user_stores")
                    .whereField("userId", isEqualTo: currentUserId)
                    .getDocuments { [weak self] countSnapshot, countError in
                        guard let self = self else {
                            #if DEBUG
                            print("🟢 MessagingService.acceptSharedStore: ERROR - self is nil in count callback")
                            #endif
                            return
                        }

                        if let countError = countError {
                            #if DEBUG
                            print("🟢 MessagingService.acceptSharedStore: ERROR getting count - \(countError)")
                            #endif
                            completion(.failure(countError))
                            return
                        }

                        let sortOrder = countSnapshot?.documents.count ?? 0
                        #if DEBUG
                        print("🟢 MessagingService.acceptSharedStore: sortOrder=\(sortOrder), permission=\(linkedStore.permission)")
                        #endif

                        // Create the user_store based on permission
                        if linkedStore.permission == "edit" {
                            #if DEBUG
                            print("🟢 MessagingService.acceptSharedStore: Creating with EDIT permission...")
                            #endif
                            self.createSharedStoreWithEditPermission(
                                linkedStore: linkedStore,
                                currentUserId: currentUserId,
                                currentUserEmail: currentUserEmail,
                                senderUserId: senderUserId,
                                senderUserStoreId: senderUserStoreId,
                                senderName: senderName,
                                senderEmail: linkedStore.senderEmail,
                                sortOrder: sortOrder,
                                messageId: messageId,
                                completion: completion
                            )
                        } else {
                            #if DEBUG
                            print("🟢 MessagingService.acceptSharedStore: Creating with VIEW permission...")
                            #endif
                            self.createSharedStoreWithViewPermission(
                                linkedStore: linkedStore,
                                currentUserId: currentUserId,
                                currentUserEmail: currentUserEmail,
                                senderUserId: senderUserId,
                                senderUserStoreId: senderUserStoreId,
                                senderName: senderName,
                                senderEmail: linkedStore.senderEmail,
                                sortOrder: sortOrder,
                                messageId: messageId,
                                completion: completion
                            )
                        }
                    }
            }
    }

    /// Create a shared store with edit permission (creates SharedStoreGroup)
    private func createSharedStoreWithEditPermission(
        linkedStore: LinkedStore,
        currentUserId: String,
        currentUserEmail: String,
        senderUserId: String,
        senderUserStoreId: String?,
        senderName: String,
        senderEmail: String?,
        sortOrder: Int,
        messageId: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        #if DEBUG
        print("🟡 createSharedStoreWithEditPermission: Starting...")
        #endif

        // Create recipient's user_store document with edit permission
        // Note: We don't create SharedStoreGroup here because recipient can't modify sender's data
        // The shared functionality works through the storeId being the same
        var recipientUserStore: [String: Any] = [
            "userId": currentUserId,
            "userEmail": currentUserEmail,
            "storeId": linkedStore.storeId,
            "storeName": linkedStore.storeName,
            "storeAddress": linkedStore.storeAddress ?? "",
            "addedAt": Date().timeIntervalSince1970,
            "sortOrder": sortOrder,
            "permission": "edit",
            "sharedFrom": senderUserId,
            "sharedFromName": senderName,  // Store sender's name for display
            "sharedAt": Date().timeIntervalSince1970,
            "notificationsEnabled": true
        ]

        // Store sender's email for Firestore rule validation (allows owner to remove access)
        if let senderEmail = senderEmail {
            recipientUserStore["sharedFromEmail"] = senderEmail
        }

        // Link to sender's user_store for reference
        if let senderUserStoreId = senderUserStoreId {
            recipientUserStore["sourceUserStoreId"] = senderUserStoreId
        }

        if let latitude = linkedStore.storeLatitude {
            recipientUserStore["latitude"] = latitude
        }
        if let longitude = linkedStore.storeLongitude {
            recipientUserStore["longitude"] = longitude
        }
        if let imageURL = linkedStore.storeImageURL {
            recipientUserStore["imageURL"] = imageURL
        }

        #if DEBUG
        print("🟡 createSharedStoreWithEditPermission: Creating recipient's user_store...")
        #endif

        db.collection("user_stores").addDocument(data: recipientUserStore) { [weak self] error in
            if let error = error {
                #if DEBUG
                print("🟡 createSharedStoreWithEditPermission: ERROR creating store - \(error)")
                #endif
                completion(.failure(error))
                return
            }
            #if DEBUG
            print("🟡 createSharedStoreWithEditPermission: SUCCESS - store created")
            #endif
            self?.updateLinkedStoreStatus(messageId: messageId, status: .accepted, completion: completion)
        }
    }

    /// Create a shared store with view-only permission
    private func createSharedStoreWithViewPermission(
        linkedStore: LinkedStore,
        currentUserId: String,
        currentUserEmail: String,
        senderUserId: String,
        senderUserStoreId: String?,
        senderName: String,
        senderEmail: String?,
        sortOrder: Int,
        messageId: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        var recipientUserStore: [String: Any] = [
            "userId": currentUserId,
            "userEmail": currentUserEmail,
            "storeId": linkedStore.storeId,
            "storeName": linkedStore.storeName,
            "storeAddress": linkedStore.storeAddress ?? "",
            "addedAt": Date().timeIntervalSince1970,
            "sortOrder": sortOrder,
            "permission": "view",
            "sharedFrom": senderUserId,
            "sharedFromName": senderName,  // Store sender's name for display
            "sharedAt": Date().timeIntervalSince1970,
            "notificationsEnabled": true
        ]

        // Store sender's email for Firestore rule validation (allows owner to remove access)
        if let senderEmail = senderEmail {
            recipientUserStore["sharedFromEmail"] = senderEmail
        }

        // For view-only, set sourceUserStoreId to point to owner's user_store for reminders
        if let sourceId = senderUserStoreId {
            recipientUserStore["sourceUserStoreId"] = sourceId
        }

        if let latitude = linkedStore.storeLatitude {
            recipientUserStore["latitude"] = latitude
        }
        if let longitude = linkedStore.storeLongitude {
            recipientUserStore["longitude"] = longitude
        }
        if let imageURL = linkedStore.storeImageURL {
            recipientUserStore["imageURL"] = imageURL
        }

        db.collection("user_stores").addDocument(data: recipientUserStore) { [weak self] error in
            if let error = error {
                #if DEBUG
                print("MessagingService: Error creating view-only user_store: \(error.localizedDescription)")
                #endif
                completion(.failure(error))
                return
            }

            #if DEBUG
            print("MessagingService: Successfully created view-only shared store")
            #endif
            self?.updateLinkedStoreStatus(messageId: messageId, status: .accepted, completion: completion)
        }
    }

    /// Accept a shared reminder - adds the store and reminder to the user's list and links them for sync
    func acceptSharedReminder(
        messageId: String,
        linkedReminder: LinkedReminder,
        currentUserId: String,
        currentUserEmail: String,
        senderName: String,
        recipientName: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard let storeId = linkedReminder.storeId else {
            completion(.failure(NSError(domain: "MessagingService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Missing store ID"])))
            return
        }

        #if DEBUG
        print("MessagingService: Accepting shared reminder for store: \(linkedReminder.storeName)")
        #endif

        // Generate a unique sharedReminderId to link the reminders
        let sharedReminderId = UUID().uuidString

        // Step 1: Check if user already has this store
        db.collection("user_stores")
            .whereField("userId", isEqualTo: currentUserId)
            .whereField("storeId", isEqualTo: storeId)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }

                if let error = error {
                    completion(.failure(error))
                    return
                }

                if let existingDoc = snapshot?.documents.first {
                    // User already has this store, add the reminder to it
                    let userStoreId = existingDoc.documentID
                    let data = existingDoc.data()

                    // Determine the correct reminder store ID based on permission
                    let sharedStoreGroupId = data["sharedStoreGroupId"] as? String
                    let sourceUserStoreId = data["sourceUserStoreId"] as? String

                    // Priority: sourceUserStoreId (view only) > sharedStoreGroupId (can edit) > userStoreId (owner)
                    let reminderStoreId = sourceUserStoreId ?? sharedStoreGroupId ?? userStoreId

                    self.addReminderToStore(
                        userStoreId: reminderStoreId,
                        reminderTitle: linkedReminder.reminderTitle,
                        originalReminderId: linkedReminder.reminderId,
                        senderName: senderName,
                        recipientName: recipientName,
                        sharedReminderId: sharedReminderId,
                        messageId: messageId,
                        completion: completion
                    )
                } else {
                    // User doesn't have this store, add store first then add reminder
                    self.addStoreAndReminder(
                        storeId: storeId,
                        linkedReminder: linkedReminder,
                        currentUserId: currentUserId,
                        currentUserEmail: currentUserEmail,
                        senderName: senderName,
                        recipientName: recipientName,
                        sharedReminderId: sharedReminderId,
                        messageId: messageId,
                        completion: completion
                    )
                }
            }
    }

    /// Add a reminder to an existing user store and link to sender's reminder
    private func addReminderToStore(
        userStoreId: String,
        reminderTitle: String,
        originalReminderId: String?,
        senderName: String,
        recipientName: String,
        sharedReminderId: String,
        messageId: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        // Check if this reminder already exists (by title)
        db.collection("reminders")
            .whereField("userStoreId", isEqualTo: userStoreId)
            .whereField("title", isEqualTo: reminderTitle)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }

                if let error = error {
                    completion(.failure(error))
                    return
                }

                if snapshot?.documents.isEmpty == false {
                    // Reminder with same title already exists, just update status
                    #if DEBUG
                    print("MessagingService: Reminder '\(reminderTitle)' already exists, marking as shared")
                    #endif
                    self.updateLinkedReminderStatus(messageId: messageId, status: .accepted, completion: completion)
                    return
                }

                // Create the recipient's reminder with sharedReminderId
                // Include both sender and recipient in sharedWith so everyone sees who it's shared with
                let reminderData: [String: Any] = [
                    "userStoreId": userStoreId,
                    "title": reminderTitle,
                    "isDone": false,
                    "createdAt": Date().timeIntervalSince1970,
                    "isShared": true,
                    "sharedFrom": senderName,
                    "sharedAt": Date().timeIntervalSince1970,
                    "sharedReminderId": sharedReminderId,
                    "sharedWith": [senderName, recipientName]
                ]

                self.db.collection("reminders").addDocument(data: reminderData) { [weak self] error in
                    guard let self = self else { return }

                    if let error = error {
                        completion(.failure(error))
                        return
                    }

                    // Update the original sender's reminder to link them
                    self.updateSenderReminder(
                        originalReminderId: originalReminderId,
                        recipientName: recipientName,
                        sharedReminderId: sharedReminderId,
                        messageId: messageId,
                        completion: completion
                    )
                }
            }
    }

    /// Update the sender's original reminder with sharedReminderId and sharedWith, then sync to all linked reminders
    private func updateSenderReminder(
        originalReminderId: String?,
        recipientName: String,
        sharedReminderId: String,
        messageId: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard let reminderId = originalReminderId else {
            // No original reminder ID, just update message status
            #if DEBUG
            print("MessagingService: No original reminder ID, skipping sender update")
            #endif
            self.updateLinkedReminderStatus(messageId: messageId, status: .accepted, completion: completion)
            return
        }

        // Get the original reminder to check existing sharedWith
        db.collection("reminders").document(reminderId).getDocument { [weak self] snapshot, error in
            guard let self = self else { return }

            if let error = error {
                #if DEBUG
                print("MessagingService: Error fetching original reminder: \(error.localizedDescription)")
                #endif
                // Still mark as accepted even if we can't update sender
                self.updateLinkedReminderStatus(messageId: messageId, status: .accepted, completion: completion)
                return
            }

            var sharedWith = snapshot?.data()?["sharedWith"] as? [String] ?? []
            if !sharedWith.contains(recipientName) {
                sharedWith.append(recipientName)
            }

            // Update sender's reminder with sharedReminderId and sharedWith
            self.db.collection("reminders").document(reminderId).updateData([
                "isShared": true,
                "sharedReminderId": sharedReminderId,
                "sharedWith": sharedWith,
                "sharedAt": Date().timeIntervalSince1970
            ]) { [weak self] error in
                guard let self = self else { return }

                if let error = error {
                    #if DEBUG
                    print("MessagingService: Error updating sender reminder: \(error.localizedDescription)")
                    #endif
                    self.updateLinkedReminderStatus(messageId: messageId, status: .accepted, completion: completion)
                    return
                }

                #if DEBUG
                print("MessagingService: Updated sender reminder with sharedReminderId and sharedWith")
                #endif

                // Sync sharedWith to ALL linked reminders so everyone sees the complete list
                self.syncSharedWithAcrossLinkedReminders(sharedReminderId: sharedReminderId, sharedWith: sharedWith) {
                    self.updateLinkedReminderStatus(messageId: messageId, status: .accepted, completion: completion)
                }
            }
        }
    }

    /// Sync the sharedWith array across all reminders with the same sharedReminderId
    private func syncSharedWithAcrossLinkedReminders(
        sharedReminderId: String,
        sharedWith: [String],
        completion: @escaping () -> Void
    ) {
        db.collection("reminders")
            .whereField("sharedReminderId", isEqualTo: sharedReminderId)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else {
                    completion()
                    return
                }

                if let error = error {
                    #if DEBUG
                    print("MessagingService: Error finding linked reminders for sync: \(error.localizedDescription)")
                    #endif
                    completion()
                    return
                }

                guard let documents = snapshot?.documents, !documents.isEmpty else {
                    completion()
                    return
                }

                // Batch update all linked reminders with the same sharedWith
                let batch = self.db.batch()
                for doc in documents {
                    batch.updateData(["sharedWith": sharedWith], forDocument: doc.reference)
                }

                batch.commit { error in
                    #if DEBUG
                    if let error = error {
                        print("MessagingService: Error syncing sharedWith: \(error.localizedDescription)")
                    } else {
                        print("MessagingService: Synced sharedWith across \(documents.count) linked reminders")
                    }
                    #endif
                    completion()
                }
            }
    }

    /// Add a new store and reminder for the user
    private func addStoreAndReminder(
        storeId: String,
        linkedReminder: LinkedReminder,
        currentUserId: String,
        currentUserEmail: String,
        senderName: String,
        recipientName: String,
        sharedReminderId: String,
        messageId: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        // Get user's current store count for sortOrder
        db.collection("user_stores")
            .whereField("userId", isEqualTo: currentUserId)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }

                if let error = error {
                    completion(.failure(error))
                    return
                }

                let sortOrder = snapshot?.documents.count ?? 0

                // Create user_store document with "edit" permission since it's shared
                var userStoreData: [String: Any] = [
                    "userId": currentUserId,
                    "userEmail": currentUserEmail,
                    "storeId": storeId,
                    "storeName": linkedReminder.storeName,
                    "storeAddress": linkedReminder.storeAddress ?? "",
                    "addedAt": Date().timeIntervalSince1970,
                    "sortOrder": sortOrder,
                    "permission": "edit",
                    "notificationsEnabled": true,
                    "sharedFrom": senderName,
                    "sharedAt": Date().timeIntervalSince1970
                ]

                if let latitude = linkedReminder.storeLatitude {
                    userStoreData["latitude"] = latitude
                }
                if let longitude = linkedReminder.storeLongitude {
                    userStoreData["longitude"] = longitude
                }
                if let imageURL = linkedReminder.storeImageURL {
                    userStoreData["imageURL"] = imageURL
                }

                // Create user_store first
                var userStoreRef: DocumentReference?
                userStoreRef = self.db.collection("user_stores").addDocument(data: userStoreData) { [weak self] error in
                    guard let self = self else { return }

                    if let error = error {
                        completion(.failure(error))
                        return
                    }

                    guard let userStoreId = userStoreRef?.documentID else {
                        completion(.failure(NSError(domain: "MessagingService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create user store"])))
                        return
                    }

                    #if DEBUG
                    print("MessagingService: Created user_store: \(userStoreId)")
                    #endif

                    // Now create the reminder with sharedReminderId
                    // Include both sender and recipient in sharedWith so everyone sees who it's shared with
                    let reminderData: [String: Any] = [
                        "userStoreId": userStoreId,
                        "title": linkedReminder.reminderTitle,
                        "isDone": false,
                        "createdAt": Date().timeIntervalSince1970,
                        "isShared": true,
                        "sharedFrom": senderName,
                        "sharedAt": Date().timeIntervalSince1970,
                        "sharedReminderId": sharedReminderId,
                        "sharedWith": [senderName, recipientName]
                    ]

                    self.db.collection("reminders").addDocument(data: reminderData) { [weak self] error in
                        guard let self = self else { return }

                        if let error = error {
                            completion(.failure(error))
                            return
                        }

                        #if DEBUG
                        print("MessagingService: Created shared reminder with sharedReminderId")
                        #endif

                        // Update the original sender's reminder to link them
                        self.updateSenderReminder(
                            originalReminderId: linkedReminder.reminderId,
                            recipientName: recipientName,
                            sharedReminderId: sharedReminderId,
                            messageId: messageId,
                            completion: completion
                        )
                    }
                }
            }
    }

    // MARK: - Incoming Message Notifications

    /// Start listening for incoming messages to trigger notifications
    func startListeningForIncomingMessages(userId: String) {
        // Stop any existing listener
        stopListeningForIncomingMessages()

        // Record the time we start listening to avoid notifying for old messages
        listenerStartTime = Date().timeIntervalSince1970

        #if DEBUG
        print("📬 MessagingService: Starting to listen for incoming messages for user: \(userId)")
        #endif

        // First, get all conversations the user is part of
        db.collection("conversations")
            .whereField("participantIds", arrayContains: userId)
            .addSnapshotListener { [weak self] conversationsSnapshot, error in
                guard let self = self else { return }

                if let error = error {
                    #if DEBUG
                    print("📬 MessagingService: Error fetching conversations: \(error.localizedDescription)")
                    #endif
                    return
                }

                guard let conversations = conversationsSnapshot?.documents else {
                    #if DEBUG
                    print("📬 MessagingService: No conversations found")
                    #endif
                    return
                }

                let conversationIds = conversations.map { $0.documentID }
                #if DEBUG
                print("📬 MessagingService: Monitoring \(conversationIds.count) conversations for new messages")
                #endif

                // Now listen for new messages in these conversations
                self.setupMessageListener(conversationIds: conversationIds, currentUserId: userId)
            }
    }

    /// Set up listener for messages in the given conversations
    private func setupMessageListener(conversationIds: [String], currentUserId: String) {
        // Stop existing message listener if any
        incomingMessageListener?.remove()

        guard !conversationIds.isEmpty else {
            #if DEBUG
            print("📬 MessagingService: No conversations to monitor")
            #endif
            return
        }

        // Firestore has a limit of 30 items in 'in' queries, so we need to handle that
        let chunkedIds = stride(from: 0, to: conversationIds.count, by: 30).map {
            Array(conversationIds[$0..<min($0 + 30, conversationIds.count)])
        }

        // For simplicity, we'll just listen to the first chunk if there are many conversations
        // In a production app, you might want to set up multiple listeners
        let idsToMonitor = chunkedIds.first ?? []

        incomingMessageListener = db.collection("messages")
            .whereField("conversationId", in: idsToMonitor)
            .whereField("createdAt", isGreaterThan: listenerStartTime)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }

                if let error = error {
                    #if DEBUG
                    print("📬 MessagingService: Error listening for messages: \(error.localizedDescription)")
                    #endif
                    return
                }

                guard let documents = snapshot?.documents else { return }

                // Process only new documents that haven't been notified yet
                for doc in documents {
                    let messageId = doc.documentID

                    // Skip if we already notified for this message
                    guard !self.notifiedMessageIds.contains(messageId) else { continue }

                    let data = doc.data()

                    // Skip messages from the current user
                    guard let senderId = data["senderId"] as? String,
                          senderId != currentUserId else { continue }

                    // Get message details
                    guard let senderName = data["senderName"] as? String,
                          let content = data["content"] as? String,
                          let conversationId = data["conversationId"] as? String,
                          let createdAt = data["createdAt"] as? TimeInterval else { continue }

                    // Only notify for messages created after we started listening
                    guard createdAt > self.listenerStartTime else { continue }

                    // Mark as notified
                    self.notifiedMessageIds.insert(messageId)

                    // Determine notification content based on message type
                    var notificationContent = content

                    // Check for linked reminder or store
                    if let linkedReminder = data["linkedReminder"] as? [String: Any],
                       let reminderTitle = linkedReminder["reminderTitle"] as? String {
                        notificationContent = "Shared a reminder: \(reminderTitle)"
                    } else if let linkedStore = data["linkedStore"] as? [String: Any],
                              let storeName = linkedStore["storeName"] as? String {
                        notificationContent = "Shared a store: \(storeName)"
                    }

                    // Schedule the notification
                    #if DEBUG
                    print("📬 MessagingService: New message from \(senderName): \(notificationContent.prefix(50))...")
                    #endif
                    NotificationManager.shared.scheduleNewMessageNotification(
                        fromUserName: senderName,
                        messageContent: notificationContent,
                        conversationId: conversationId
                    )
                }
            }
    }

    /// Stop listening for incoming messages
    func stopListeningForIncomingMessages() {
        incomingMessageListener?.remove()
        incomingMessageListener = nil
        notifiedMessageIds.removeAll()
        #if DEBUG
        print("📬 MessagingService: Stopped listening for incoming messages")
        #endif
    }
}
