//
//  TutorialMockData.swift
//  Geolocation_v1.0.0
//
//  Provides fake data used to populate views during the onboarding tutorial.
//  None of this data is written to Firestore.
//

import Foundation

enum TutorialMockData {

    // MARK: - Stores

    static var stores: [UserStoreItem] {
        let wholeFoods = Store(id: "tutorial_whole-foods", name: "Whole Foods", reminderCount: 3)
        let target     = Store(id: "tutorial_target",     name: "Target",      reminderCount: 2)
        let cvs        = Store(id: "tutorial_cvs",        name: "CVS Pharmacy",reminderCount: 1)

        return [
            UserStoreItem(
                id: "tutorial_us_1",
                store: wholeFoods,
                permission: .owner,
                sharedStoreGroupId: nil,
                sourceUserStoreId: nil,
                sharedFromName: nil,
                sharedFromId: nil,
                sharedWith: nil,
                notificationsEnabled: true
            ),
            UserStoreItem(
                id: "tutorial_us_2",
                store: target,
                permission: .owner,
                sharedStoreGroupId: nil,
                sourceUserStoreId: nil,
                sharedFromName: nil,
                sharedFromId: nil,
                sharedWith: nil,
                notificationsEnabled: true
            ),
            UserStoreItem(
                id: "tutorial_us_3",
                store: cvs,
                permission: .owner,
                sharedStoreGroupId: nil,
                sourceUserStoreId: nil,
                sharedFromName: nil,
                sharedFromId: nil,
                sharedWith: nil,
                notificationsEnabled: true
            ),
        ]
    }

    // MARK: - Conversations

    /// Builds mock conversations using the real current user ID so that
    /// `otherParticipantName(currentUserId:)` resolves correctly.
    static func conversations(currentUserId: String) -> [Conversation] {
        let now = Date().timeIntervalSince1970
        return [
            Conversation(
                id: "tutorial_conv_1",
                participantIds: [currentUserId, "tutorial_mom"],
                participantNames: [currentUserId: "You", "tutorial_mom": "Mom"],
                createdAt: now - 3600,
                lastMessageContent: "Don't forget the milk! 🥛",
                lastMessageAt: now - 60,
                lastMessageSenderId: "tutorial_mom",
                unreadCount: [currentUserId: 1]
            ),
            Conversation(
                id: "tutorial_conv_2",
                participantIds: [currentUserId, "tutorial_alex"],
                participantNames: [currentUserId: "You", "tutorial_alex": "Alex"],
                createdAt: now - 86400,
                lastMessageContent: "Did you pick up the groceries?",
                lastMessageAt: now - 86400,
                lastMessageSenderId: "tutorial_alex",
                unreadCount: [currentUserId: 0]
            ),
        ]
    }

    // MARK: - Friendships

    static var familyFriendships: [Friendship] {
        let now = Date().timeIntervalSince1970
        return [
            Friendship(
                id: "tutorial_fs_mom",
                requesterId: "tutorial_mom",
                requesterName: "Mom",
                requesterEmail: "mom@example.com",
                requesterProfilePictureURL: nil,
                receiverId: "tutorial_self",
                receiverName: "You",
                receiverEmail: "you@example.com",
                receiverProfilePictureURL: nil,
                status: .accepted,
                createdAt: now - 100000,
                acceptedAt: now - 90000
            ),
            Friendship(
                id: "tutorial_fs_dad",
                requesterId: "tutorial_dad",
                requesterName: "Dad",
                requesterEmail: "dad@example.com",
                requesterProfilePictureURL: nil,
                receiverId: "tutorial_self",
                receiverName: "You",
                receiverEmail: "you@example.com",
                receiverProfilePictureURL: nil,
                status: .accepted,
                createdAt: now - 100000,
                acceptedAt: now - 90000
            ),
        ]
    }

    static var friendFriendships: [Friendship] {
        let now = Date().timeIntervalSince1970
        return [
            Friendship(
                id: "tutorial_fs_alex",
                requesterId: "tutorial_alex",
                requesterName: "Alex",
                requesterEmail: "alex@example.com",
                requesterProfilePictureURL: nil,
                receiverId: "tutorial_self",
                receiverName: "You",
                receiverEmail: "you@example.com",
                receiverProfilePictureURL: nil,
                status: .accepted,
                createdAt: now - 50000,
                acceptedAt: now - 40000
            ),
            Friendship(
                id: "tutorial_fs_jamie",
                requesterId: "tutorial_jamie",
                requesterName: "Jamie",
                requesterEmail: "jamie@example.com",
                requesterProfilePictureURL: nil,
                receiverId: "tutorial_self",
                receiverName: "You",
                receiverEmail: "you@example.com",
                receiverProfilePictureURL: nil,
                status: .accepted,
                createdAt: now - 30000,
                acceptedAt: now - 20000
            ),
        ]
    }
}
