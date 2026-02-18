//
//  Reminder.swift
//  Geolocation_v1.0.0
//
//  Created by James Jeon on 10/14/24.
//

import Foundation

struct Reminder: Codable, Identifiable {
    var id: String // Firestore document ID
    let userStoreId: String // References user_stores document ID
    var title: String
    var isDone: Bool
    let createdAt: TimeInterval

    // Shared reminder tracking
    var isShared: Bool? // True if this reminder is shared with another user
    var sharedFrom: String? // Name of the user who shared it (for receiver)
    var sharedAt: TimeInterval? // When it was shared/accepted

    // Sync fields for linking shared reminders
    var sharedReminderId: String? // Unique ID linking all instances of the same shared reminder
    var sharedWith: [String]? // Array of user names this reminder is shared with (for sender)

    // Photo attachments
    var photoURLs: [String]? // Array of Firebase Storage download URLs for attached photos

    // Custom sort order for manual reordering
    var sortOrder: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case userStoreId
        case title
        case isDone
        case createdAt
        case isShared
        case sharedFrom
        case sharedAt
        case sharedReminderId
        case sharedWith
        case photoURLs
        case sortOrder
    }
}
