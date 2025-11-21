//
//  UserStoreItem.swift
//  Geolocation_v1.0.0
//
//  Created by Claude on 11/6/24.
//

import Foundation

/// Represents a store that a user has added to their list
/// Combines store information with the user_store document ID
struct UserStoreItem: Identifiable, Hashable {
    let id: String // user_store document ID
    let store: Store
}
