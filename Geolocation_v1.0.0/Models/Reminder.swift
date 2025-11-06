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

    enum CodingKeys: String, CodingKey {
        case id
        case userStoreId
        case title
        case isDone
        case createdAt
    }
}
