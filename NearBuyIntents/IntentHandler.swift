//
//  IntentHandler.swift
//  NearBuyIntents
//
//  Created by Claude Code
//

import Intents
import FirebaseCore
import FirebaseFirestore
import FirebaseAuth

class IntentHandler: INExtension {

    override func handler(for intent: INIntent) -> Any {
        // Initialize Firebase if needed
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }

        switch intent {
        case is INSendMessageIntent:
            return SendMessageIntentHandler()
        case is INSearchForMessagesIntent:
            return SearchMessagesIntentHandler()
        case is INSetMessageAttributeIntent:
            return SetMessageAttributeIntentHandler()
        default:
            return self
        }
    }
}

// MARK: - Send Message Intent Handler

class SendMessageIntentHandler: NSObject, INSendMessageIntentHandling {

    private let db = Firestore.firestore()

    // MARK: - Resolution

    func resolveRecipients(for intent: INSendMessageIntent, with completion: @escaping ([INSendMessageRecipientResolutionResult]) -> Void) {
        guard let recipients = intent.recipients, !recipients.isEmpty else {
            completion([INSendMessageRecipientResolutionResult.needsValue()])
            return
        }

        var results: [INSendMessageRecipientResolutionResult] = []

        let dispatchGroup = DispatchGroup()

        for recipient in recipients {
            dispatchGroup.enter()

            if let displayName = recipient.displayName {
                // Search for user by name
                searchUser(byName: displayName) { person in
                    if let person = person {
                        results.append(.success(with: person))
                    } else {
                        results.append(.unsupported())
                    }
                    dispatchGroup.leave()
                }
            } else {
                results.append(.unsupported())
                dispatchGroup.leave()
            }
        }

        dispatchGroup.notify(queue: .main) {
            completion(results)
        }
    }

    func resolveContent(for intent: INSendMessageIntent, with completion: @escaping (INStringResolutionResult) -> Void) {
        if let content = intent.content, !content.isEmpty {
            completion(.success(with: content))
        } else {
            completion(.needsValue())
        }
    }

    // MARK: - Confirmation

    func confirm(intent: INSendMessageIntent, completion: @escaping (INSendMessageIntentResponse) -> Void) {
        guard Auth.auth().currentUser != nil else {
            completion(INSendMessageIntentResponse(code: .failureRequiringAppLaunch, userActivity: nil))
            return
        }

        completion(INSendMessageIntentResponse(code: .ready, userActivity: nil))
    }

    // MARK: - Handling

    func handle(intent: INSendMessageIntent, completion: @escaping (INSendMessageIntentResponse) -> Void) {
        guard let currentUser = Auth.auth().currentUser,
              let recipients = intent.recipients, !recipients.isEmpty,
              let content = intent.content else {
            completion(INSendMessageIntentResponse(code: .failure, userActivity: nil))
            return
        }

        let recipientId = recipients.first?.personHandle?.value ?? ""

        // Find or create conversation
        findOrCreateConversation(currentUserId: currentUser.uid, recipientId: recipientId) { [weak self] conversationId in
            guard let conversationId = conversationId else {
                completion(INSendMessageIntentResponse(code: .failure, userActivity: nil))
                return
            }

            // Send message
            self?.sendMessage(
                conversationId: conversationId,
                senderId: currentUser.uid,
                senderName: currentUser.displayName ?? "User",
                content: content
            ) { success in
                if success {
                    let response = INSendMessageIntentResponse(code: .success, userActivity: nil)
                    response.sentMessage = INMessage(
                        identifier: UUID().uuidString,
                        conversationIdentifier: conversationId,
                        content: content,
                        dateSent: Date(),
                        sender: INPerson(
                            personHandle: INPersonHandle(value: currentUser.uid, type: .unknown),
                            nameComponents: nil,
                            displayName: currentUser.displayName ?? "Me",
                            image: nil,
                            contactIdentifier: nil,
                            customIdentifier: currentUser.uid
                        ),
                        recipients: recipients,
                        groupName: nil,
                        messageType: .text
                    )
                    completion(response)
                } else {
                    completion(INSendMessageIntentResponse(code: .failure, userActivity: nil))
                }
            }
        }
    }

    // MARK: - Helpers

    private func searchUser(byName name: String, completion: @escaping (INPerson?) -> Void) {
        db.collection("users")
            .whereField("name", isEqualTo: name)
            .limit(to: 1)
            .getDocuments { snapshot, error in
                guard let doc = snapshot?.documents.first else {
                    completion(nil)
                    return
                }

                let data = doc.data()
                let userId = doc.documentID
                let userName = data["name"] as? String ?? name

                let person = INPerson(
                    personHandle: INPersonHandle(value: userId, type: .unknown),
                    nameComponents: nil,
                    displayName: userName,
                    image: nil,
                    contactIdentifier: nil,
                    customIdentifier: userId
                )

                completion(person)
            }
    }

    private func findOrCreateConversation(currentUserId: String, recipientId: String, completion: @escaping (String?) -> Void) {
        // First try to find existing conversation
        db.collection("conversations")
            .whereField("participantIds", arrayContains: currentUserId)
            .getDocuments { [weak self] snapshot, error in
                if let existingDoc = snapshot?.documents.first(where: { doc in
                    guard let participantIds = doc.data()["participantIds"] as? [String] else { return false }
                    return participantIds.contains(recipientId)
                }) {
                    completion(existingDoc.documentID)
                    return
                }

                // Create new conversation
                self?.createConversation(currentUserId: currentUserId, recipientId: recipientId, completion: completion)
            }
    }

    private func createConversation(currentUserId: String, recipientId: String, completion: @escaping (String?) -> Void) {
        let conversationData: [String: Any] = [
            "participantIds": [currentUserId, recipientId],
            "participantNames": [:],
            "createdAt": Date().timeIntervalSince1970,
            "lastMessageContent": NSNull(),
            "lastMessageAt": NSNull(),
            "lastMessageSenderId": NSNull(),
            "unreadCount": [currentUserId: 0, recipientId: 0]
        ]

        var ref: DocumentReference?
        ref = db.collection("conversations").addDocument(data: conversationData) { error in
            completion(error == nil ? ref?.documentID : nil)
        }
    }

    private func sendMessage(conversationId: String, senderId: String, senderName: String, content: String, completion: @escaping (Bool) -> Void) {
        let messageData: [String: Any] = [
            "conversationId": conversationId,
            "senderId": senderId,
            "senderName": senderName,
            "content": content,
            "createdAt": Date().timeIntervalSince1970,
            "isRead": false
        ]

        db.collection("messages").addDocument(data: messageData) { [weak self] error in
            if error == nil {
                // Update conversation
                self?.db.collection("conversations").document(conversationId).updateData([
                    "lastMessageContent": content,
                    "lastMessageAt": Date().timeIntervalSince1970,
                    "lastMessageSenderId": senderId
                ])
            }
            completion(error == nil)
        }
    }
}

// MARK: - Search Messages Intent Handler

class SearchMessagesIntentHandler: NSObject, INSearchForMessagesIntentHandling {

    private let db = Firestore.firestore()

    func handle(intent: INSearchForMessagesIntent, completion: @escaping (INSearchForMessagesIntentResponse) -> Void) {
        guard let currentUser = Auth.auth().currentUser else {
            completion(INSearchForMessagesIntentResponse(code: .failureRequiringAppLaunch, userActivity: nil))
            return
        }

        // Get user's conversations
        db.collection("conversations")
            .whereField("participantIds", arrayContains: currentUser.uid)
            .getDocuments { [weak self] snapshot, error in
                guard let documents = snapshot?.documents, !documents.isEmpty else {
                    let response = INSearchForMessagesIntentResponse(code: .success, userActivity: nil)
                    response.messages = []
                    completion(response)
                    return
                }

                let conversationIds = documents.map { $0.documentID }
                self?.fetchMessages(conversationIds: conversationIds, intent: intent, currentUserId: currentUser.uid, completion: completion)
            }
    }

    private func fetchMessages(conversationIds: [String], intent: INSearchForMessagesIntent, currentUserId: String, completion: @escaping (INSearchForMessagesIntentResponse) -> Void) {
        var query: Query = db.collection("messages")
            .whereField("conversationId", in: conversationIds)
            .order(by: "createdAt", descending: true)
            .limit(to: 20)

        // Filter by sender if specified
        if let senders = intent.senders, let firstSender = senders.first,
           let senderId = firstSender.customIdentifier {
            query = query.whereField("senderId", isEqualTo: senderId)
        }

        // Filter by unread if specified
        if intent.attributes == .unread {
            query = query.whereField("isRead", isEqualTo: false)
                .whereField("senderId", isNotEqualTo: currentUserId)
        }

        query.getDocuments { snapshot, error in
            guard let documents = snapshot?.documents else {
                completion(INSearchForMessagesIntentResponse(code: .failure, userActivity: nil))
                return
            }

            let messages = documents.compactMap { doc -> INMessage? in
                let data = doc.data()
                guard let conversationId = data["conversationId"] as? String,
                      let senderId = data["senderId"] as? String,
                      let senderName = data["senderName"] as? String,
                      let content = data["content"] as? String,
                      let createdAt = data["createdAt"] as? TimeInterval else {
                    return nil
                }

                let sender = INPerson(
                    personHandle: INPersonHandle(value: senderId, type: .unknown),
                    nameComponents: nil,
                    displayName: senderName,
                    image: nil,
                    contactIdentifier: nil,
                    customIdentifier: senderId
                )

                return INMessage(
                    identifier: doc.documentID,
                    conversationIdentifier: conversationId,
                    content: content,
                    dateSent: Date(timeIntervalSince1970: createdAt),
                    sender: sender,
                    recipients: [],
                    groupName: nil,
                    messageType: .text
                )
            }

            let response = INSearchForMessagesIntentResponse(code: .success, userActivity: nil)
            response.messages = messages
            completion(response)
        }
    }
}

// MARK: - Set Message Attribute Intent Handler

class SetMessageAttributeIntentHandler: NSObject, INSetMessageAttributeIntentHandling {

    private let db = Firestore.firestore()

    func handle(intent: INSetMessageAttributeIntent, completion: @escaping (INSetMessageAttributeIntentResponse) -> Void) {
        guard let identifiers = intent.identifiers, !identifiers.isEmpty else {
            completion(INSetMessageAttributeIntentResponse(code: .failure, userActivity: nil))
            return
        }

        let batch = db.batch()

        for identifier in identifiers {
            let docRef = db.collection("messages").document(identifier)

            switch intent.attribute {
            case .read:
                batch.updateData(["isRead": true], forDocument: docRef)
            case .unread:
                batch.updateData(["isRead": false], forDocument: docRef)
            default:
                break
            }
        }

        batch.commit { error in
            if error == nil {
                completion(INSetMessageAttributeIntentResponse(code: .success, userActivity: nil))
            } else {
                completion(INSetMessageAttributeIntentResponse(code: .failure, userActivity: nil))
            }
        }
    }
}
