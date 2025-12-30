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
    let title: String
    var isDone: Bool
    let createdAt: TimeInterval

    // Shared reminder tracking
    var isShared: Bool? // True if this reminder was received from another user
    var sharedFrom: String? // Email or name of the user who shared it
    var sharedAt: TimeInterval? // When it was shared/accepted

    enum CodingKeys: String, CodingKey {
        case id
        case userStoreId
        case title
        case isDone
        case createdAt
        case isShared
        case sharedFrom
        case sharedAt
    }
}
