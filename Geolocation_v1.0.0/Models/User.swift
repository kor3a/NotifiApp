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
}
