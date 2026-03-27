//
//  Recipe.swift
//  Geolocation_v1.0.0
//
//  Created by Claude on 3/27/26.
//

import Foundation

struct Recipe: Codable, Identifiable {
    var id: String
    var name: String
    var ingredients: [String]
    let createdAt: TimeInterval

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case ingredients
        case createdAt
    }
}
