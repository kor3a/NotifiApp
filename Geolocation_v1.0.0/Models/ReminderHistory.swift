//
//  ReminderHistory.swift
//  Geolocation_v1.0.0
//
//  Created by James Jeon on 7/20/26.
//

import Foundation

/// A checked-off reminder that was removed from a store's list, preserved so
/// the store's HistoryView can show what was bought/completed and when.
/// Written to the `reminder_history` collection at the moment a checked-off
/// reminder is deleted (the reminder document itself is gone after that).
struct ReminderHistoryEntry: Codable, Identifiable {
    var id: String // Firestore document ID
    let userStoreId: String // Same ID space the reminder used (user_store / shared group)
    let title: String
    /// When the item was checked off (falls back to deletion time for legacy
    /// items that never recorded a check-off timestamp).
    let checkedOffAt: TimeInterval
    /// Display name of the user who checked the item off, when known.
    var checkedOffBy: String?
    var checkedOffById: String?
    /// Display name of the user who created the reminder, when known.
    var createdBy: String?
    var createdById: String?
    /// When the original reminder was created.
    var createdAt: TimeInterval?
    /// When the reminder was deleted from the list (history entry written).
    var deletedAt: TimeInterval?
    var quantity: Int?
    var photoURLs: [String]?
    var category: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userStoreId
        case title
        case checkedOffAt
        case checkedOffBy
        case checkedOffById
        case createdBy
        case createdById
        case createdAt
        case deletedAt
        case quantity
        case photoURLs
        case category
    }
}
