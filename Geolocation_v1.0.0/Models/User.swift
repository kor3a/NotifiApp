//
//  User.swift
//  Geolocation_v1.0.0
//
//  Created by Subong Jeon on 8/5/24.
//

import Foundation

struct User: Codable, Equatable {
    let userId: String
    var name: String
    let email: String
    let joined: TimeInterval
    var profilePictureURL: String?
    var familyMemberIds: [String]?
    var isSubscribed: Bool?
    /// Manually set in Firestore to grant free access. Never overwritten by the app.
    var adminSubscribed: Bool?
    /// UUID generated at signup and stored in Firestore. Passed as StoreKit's
    /// `appAccountToken` when purchasing so we can verify that an entitlement
    /// belongs to this specific app user and not another account sharing the same Apple ID.
    var subscriptionToken: String?
}
