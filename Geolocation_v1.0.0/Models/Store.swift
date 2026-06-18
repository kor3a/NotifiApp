//
//  Store.swift
//  Geolocation_v1.0.0
//
//  Created by James Jeon on 10/14/24.
//

import Foundation

struct Store: Codable, Identifiable, Hashable {
    var id: String // Firestore document ID - now based on normalized store name
    let name: String
    var reminderCount: Int = 0
    var sortOrder: Int? = nil
    var imageURL: String? = nil
    var websiteURL: String? = nil
    var appURL: String? = nil

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case reminderCount
        case sortOrder
        case imageURL
        case websiteURL
        case appURL
    }

    /// Generate a normalized store ID from a store name
    /// This ensures all locations of the same store chain share the same ID
    static func normalizedId(from name: String) -> String {
        return name
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "&", with: "and")
    }

    /// Create a Store from just a name (for name-based store tracking)
    init(name: String, reminderCount: Int = 0, sortOrder: Int? = nil, imageURL: String? = nil, websiteURL: String? = nil, appURL: String? = nil) {
        self.id = Store.normalizedId(from: name)
        self.name = name
        self.reminderCount = reminderCount
        self.sortOrder = sortOrder
        self.imageURL = imageURL
        self.websiteURL = websiteURL
        self.appURL = appURL
    }

    /// Full initializer for backward compatibility and explicit ID setting
    init(id: String, name: String, reminderCount: Int = 0, sortOrder: Int? = nil, imageURL: String? = nil, websiteURL: String? = nil, appURL: String? = nil) {
        self.id = id
        self.name = name
        self.reminderCount = reminderCount
        self.sortOrder = sortOrder
        self.imageURL = imageURL
        self.websiteURL = websiteURL
        self.appURL = appURL
    }
}
