//
//  FriendRequest.swift
//  Geolocation_v1.0.0
//
//  Created by Claude Code
//

import Foundation

/// Status of a friend request
enum FriendRequestStatus: String, Codable {
    case pending
    case accepted
    case rejected
}

/// Represents a friend request between two users
struct FriendRequest: Codable, Identifiable, Equatable {
    let id: String
    let fromUserId: String
    let toUserId: String
    let fromUserName: String
    let toUserName: String
    let fromUserEmail: String
    let toUserEmail: String
    var status: FriendRequestStatus
    let createdAt: TimeInterval
    let fromUserProfilePictureURL: String?
    let toUserProfilePictureURL: String?

    enum CodingKeys: String, CodingKey {
        case id
        case fromUserId
        case toUserId
        case fromUserName
        case toUserName
        case fromUserEmail
        case toUserEmail
        case status
        case createdAt
        case fromUserProfilePictureURL
        case toUserProfilePictureURL
    }
}
