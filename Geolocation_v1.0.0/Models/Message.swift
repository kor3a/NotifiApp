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

    enum CodingKeys: String, CodingKey {
        case id
        case conversationId
        case senderId
        case senderName
        case content
        case createdAt
        case isRead
        case linkedReminder
    }
}

/// Represents a reminder that was shared in a message
struct LinkedReminder: Codable, Equatable {
    let reminderTitle: String
    let storeName: String
    let storeAddress: String?
}

/// Represents a conversation between users
struct Conversation: Codable, Identifiable, Equatable {
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
