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

    /// Fetch messages for a conversation
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

    /// Send a message
    func sendMessage(
        conversationId: String,
        senderId: String,
        senderName: String,
        content: String,
        linkedReminder: LinkedReminder? = nil,
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
            messageData["linkedReminder"] = reminderData
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
                linkedReminder: linkedReminder
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

                let contact = Contact(
                    id: doc.documentID,
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
            linkedReminder = LinkedReminder(
                reminderTitle: reminderTitle,
                storeName: storeName,
                storeAddress: reminderData["storeAddress"] as? String
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
            linkedReminder: linkedReminder
        )
    }

    // MARK: - Total Unread Count

    /// Get total unread message count for badge
    func getTotalUnreadCount(for userId: String, completion: @escaping (Int) -> Void) {
        db.collection("conversations")
            .whereField("participantIds", arrayContains: userId)
            .addSnapshotListener { snapshot, error in
                guard let documents = snapshot?.documents else {
                    completion(0)
                    return
                }

                var totalUnread = 0
                for doc in documents {
                    let data = doc.data()
                    if let unreadCount = data["unreadCount"] as? [String: Int] {
                        totalUnread += unreadCount[userId] ?? 0
                    }
                }

                completion(totalUnread)
            }
    }
}
