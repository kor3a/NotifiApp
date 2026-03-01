//
//  FavoriteTag.swift
//  Geolocation_v1.0.0
//

import Foundation

struct FavoriteTag: Codable, Identifiable {
    var id: String // Firestore document ID
    let userStoreId: String // References user_stores document ID
    let userId: String // The app username of the user who created this tag
    let title: String // The reminder title saved as a reusable tag
    let createdAt: TimeInterval

    enum CodingKeys: String, CodingKey {
        case id
        case userStoreId
        case userId
        case title
        case createdAt
    }
}
