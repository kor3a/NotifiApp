//
//  Message.swift
//  Geolocation_v1.0.0
//
//  Created by Claude Code
//

import Foundation

/// Represents a message in a conversation
struct Message: Codable, Identifiable, Equatable {
    let id: String
    let conversationId: String
    let senderId: String
    let senderName: String
    let content: String
    let createdAt: TimeInterval
    var isRead: Bool

    // Optional: linked reminder info
    let linkedReminder: LinkedReminder?

    // Optional: linked store info (for store sharing)
    let linkedStore: LinkedStore?

    enum CodingKeys: String, CodingKey {
        case id
        case conversationId
        case senderId
        case senderName
        case content
        case createdAt
        case isRead
        case linkedReminder
        case linkedStore
    }
}

/// Status of a shared reminder or store
enum SharedReminderStatus: String, Codable {
    case pending
    case accepted
    case rejected
}

/// Represents a store that was shared in a message
struct LinkedStore: Codable, Equatable {
    let storeName: String
    let storeAddress: String?
    let storeId: String
    let senderUserId: String
    let senderUserStoreId: String? // Sender's user_store ID for linking
    var status: SharedReminderStatus?
    let permission: String // "edit" or "view"

    // Store coordinates for adding the store
    let storeLatitude: Double?
    let storeLongitude: Double?
    let storeImageURL: String?

    // List of reminder titles being shared with the store
    let reminderTitles: [String]?

    init(storeName: String, storeAddress: String?, storeId: String, senderUserId: String, senderUserStoreId: String? = nil, status: SharedReminderStatus? = .pending, permission: String = "edit", storeLatitude: Double? = nil, storeLongitude: Double? = nil, storeImageURL: String? = nil, reminderTitles: [String]? = nil) {
        self.storeName = storeName
        self.storeAddress = storeAddress
        self.storeId = storeId
        self.senderUserId = senderUserId
        self.senderUserStoreId = senderUserStoreId
        self.status = status
        self.permission = permission
        self.storeLatitude = storeLatitude
        self.storeLongitude = storeLongitude
        self.storeImageURL = storeImageURL
        self.reminderTitles = reminderTitles
    }
}

/// Represents a reminder that was shared in a message
struct LinkedReminder: Codable, Equatable {
    let reminderTitle: String
    let storeName: String
    let storeAddress: String?

    // Additional fields for accept/reject functionality
    let reminderId: String?
    let storeId: String?
    let senderUserId: String?
    var status: SharedReminderStatus?

    // Store coordinates for adding the store
    let storeLatitude: Double?
    let storeLongitude: Double?
    let storeImageURL: String?

    // Initializer for backward compatibility
    init(reminderTitle: String, storeName: String, storeAddress: String?, reminderId: String? = nil, storeId: String? = nil, senderUserId: String? = nil, status: SharedReminderStatus? = .pending, storeLatitude: Double? = nil, storeLongitude: Double? = nil, storeImageURL: String? = nil) {
        self.reminderTitle = reminderTitle
        self.storeName = storeName
        self.storeAddress = storeAddress
        self.reminderId = reminderId
        self.storeId = storeId
        self.senderUserId = senderUserId
        self.status = status
        self.storeLatitude = storeLatitude
        self.storeLongitude = storeLongitude
        self.storeImageURL = storeImageURL
    }
}

/// Represents a conversation between users
struct Conversation: Codable, Identifiable, Equatable, Hashable {
    let id: String
    let participantIds: [String]
    let participantNames: [String: String] // userId -> name mapping
    let createdAt: TimeInterval
    var lastMessageContent: String?
    var lastMessageAt: TimeInterval?
    var lastMessageSenderId: String?
    var unreadCount: [String: Int] // userId -> unread count

    enum CodingKeys: String, CodingKey {
        case id
        case participantIds
        case participantNames
        case createdAt
        case lastMessageContent
        case lastMessageAt
        case lastMessageSenderId
        case unreadCount
    }

    // Hashable conformance using only id
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    /// Get the other participant's name for display
    func otherParticipantName(currentUserId: String) -> String {
        for (userId, name) in participantNames {
            if userId != currentUserId {
                return name
            }
        }
        return "Unknown"
    }

    /// Get the other participant's ID
    func otherParticipantId(currentUserId: String) -> String? {
        return participantIds.first { $0 != currentUserId }
    }

    /// Get unread count for current user
    func unreadCountFor(userId: String) -> Int {
        return unreadCount[userId] ?? 0
    }
}

/// Contact model for selecting message recipients
struct Contact: Identifiable, Equatable {
    let id: String // userId
    let name: String
    let email: String
    let profilePictureURL: String?
}
