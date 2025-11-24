//
//  SharedStoreGroup.swift
//  Geolocation_v1.0.0
//
//  Created for tracking shared stores with Can Edit permission
//

import Foundation

struct SharedStoreGroup: Codable, Identifiable {
    var id: String // Firestore document ID
    let storeId: String // Reference to the store in stores collection
    var userStoreIds: [String] // Array of user_stores document IDs for all co-owners
    let createdAt: TimeInterval
    var updatedAt: TimeInterval

    enum CodingKeys: String, CodingKey {
        case id
        case storeId
        case userStoreIds
        case createdAt
        case updatedAt
    }
}
