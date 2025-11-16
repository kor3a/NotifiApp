//
//  Store.swift
//  Geolocation_v1.0.0
//
//  Created by James Jeon on 10/14/24.
//

import Foundation

struct Store: Codable, Identifiable {
    var id: String // Firestore document ID
    let name: String
    let address: String
    var reminderCount: Int = 0
    var sortOrder: Int? = nil
    var latitude: Double? = nil
    var longitude: Double? = nil

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case address
        case reminderCount
        case sortOrder
        case latitude
        case longitude
    }
}
