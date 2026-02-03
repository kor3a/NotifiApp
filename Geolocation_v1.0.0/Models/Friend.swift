//
//  Friend.swift
//  Geolocation_v1.0.0
//
//  Created by Claude Code
//

import Foundation

/// Status of a friend request
enum FriendshipStatus: String, Codable {
    case pending
    case accepted
    case rejected
}

/// Represents a friendship relationship between two users
struct Friendship: Codable, Identifiable, Equatable {
    let id: String
    let requesterId: String
    let requesterName: String
    let requesterEmail: String
    let requesterProfilePictureURL: String?
    let receiverId: String
    let receiverName: String
    let receiverEmail: String
    let receiverProfilePictureURL: String?
    var status: FriendshipStatus
    let createdAt: TimeInterval
    var acceptedAt: TimeInterval?

    enum CodingKeys: String, CodingKey {
        case id
        case requesterId
        case requesterName
        case requesterEmail
        case requesterProfilePictureURL
        case receiverId
        case receiverName
        case receiverEmail
        case receiverProfilePictureURL
        case status
        case createdAt
        case acceptedAt
    }

    /// Check if current user is the requester
    func isRequester(currentUserId: String) -> Bool {
        return requesterId == currentUserId
    }

    /// Get the other user's ID (the friend)
    func friendId(currentUserId: String) -> String {
        return requesterId == currentUserId ? receiverId : requesterId
    }

    /// Get the other user's name (the friend)
    func friendName(currentUserId: String) -> String {
        return requesterId == currentUserId ? receiverName : requesterName
    }

    /// Get the other user's email (the friend)
    func friendEmail(currentUserId: String) -> String {
        return requesterId == currentUserId ? receiverEmail : requesterEmail
    }

    /// Get the other user's profile picture URL (the friend)
    func friendProfilePictureURL(currentUserId: String) -> String? {
        return requesterId == currentUserId ? receiverProfilePictureURL : requesterProfilePictureURL
    }

    /// Convert to Contact for messaging
    func toContact(currentUserId: String) -> Contact {
        return Contact(
            id: friendId(currentUserId: currentUserId),
            name: friendName(currentUserId: currentUserId),
            email: friendEmail(currentUserId: currentUserId),
            profilePictureURL: friendProfilePictureURL(currentUserId: currentUserId)
        )
    }
}
