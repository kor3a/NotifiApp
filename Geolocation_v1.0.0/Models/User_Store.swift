import Foundation
import FirebaseFirestore

enum StorePermission: String, Codable {
    case owner = "owner"
    case edit = "edit"
    case view = "view"
}

struct UserStore: Codable, Identifiable {
    var id: String? // Firestore document ID - will be set manually from doc.documentID
    let userId: String
    let storeId: String // Now based on normalized store name
    let storeName: String // The store name (e.g., "Walmart", "Target")
    let addedAt: TimeInterval
    var permission: StorePermission = .owner // Default to owner for existing stores
    var sharedStoreGroupId: String? = nil // Links co-owners for Can Edit permission
    var sourceUserStoreId: String? = nil // For View Only: points to owner's user_store ID for fetching reminders
    var sharedFrom: String? = nil // User ID of user who shared
    var sharedFromName: String? = nil // Display name of user who shared
    var sharedFromEmail: String? = nil // Email of user who shared (for Firestore rule validation)
    var sharedAt: TimeInterval? = nil // When it was shared
    var sharedWith: [String]? = nil // Names of users this store is shared with (for owner)
    var notificationsEnabled: Bool = true // Whether notifications are enabled for this store

    /// Returns the ID to use for fetching this store's reminders, or nil if the
    /// document ID hasn't been set yet. Mirrors `UserStoreItem.reminderStoreId`:
    /// - Owners always use their own user_store ID, even if `sourceUserStoreId` is
    ///   set (the merge flow sets it for tracking purposes without changing which
    ///   reminders the owner sees).
    /// - View-only and edit recipients use `sourceUserStoreId` (owner's store) or
    ///   `sharedStoreGroupId`.
    var reminderStoreId: String? {
        guard let id = id else { return nil }
        guard permission != .owner else { return id }
        return sourceUserStoreId ?? sharedStoreGroupId ?? id
    }

    enum CodingKeys: String, CodingKey {
        // Note: id is excluded from CodingKeys and set manually from doc.documentID
        case userId
        case storeId
        case storeName
        case addedAt
        case permission
        case sharedStoreGroupId
        case sourceUserStoreId
        case sharedFrom
        case sharedFromName
        case sharedFromEmail
        case sharedAt
        case sharedWith
        case notificationsEnabled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userId = try container.decode(String.self, forKey: .userId)
        storeId = try container.decode(String.self, forKey: .storeId)
        storeName = try container.decode(String.self, forKey: .storeName)
        addedAt = try container.decode(TimeInterval.self, forKey: .addedAt)
        sharedStoreGroupId = try container.decodeIfPresent(String.self, forKey: .sharedStoreGroupId)
        sourceUserStoreId = try container.decodeIfPresent(String.self, forKey: .sourceUserStoreId)
        sharedFrom = try container.decodeIfPresent(String.self, forKey: .sharedFrom)
        sharedFromName = try container.decodeIfPresent(String.self, forKey: .sharedFromName)
        sharedFromEmail = try container.decodeIfPresent(String.self, forKey: .sharedFromEmail)
        sharedAt = try container.decodeIfPresent(TimeInterval.self, forKey: .sharedAt)
        sharedWith = try container.decodeIfPresent([String].self, forKey: .sharedWith)

        // Handle permission with default value for backward compatibility
        if let permissionString = try container.decodeIfPresent(String.self, forKey: .permission) {
            permission = StorePermission(rawValue: permissionString) ?? .owner
        } else {
            permission = .owner
        }

        // Handle notificationsEnabled with default value for backward compatibility
        notificationsEnabled = try container.decodeIfPresent(Bool.self, forKey: .notificationsEnabled) ?? true
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(userId, forKey: .userId)
        try container.encode(storeId, forKey: .storeId)
        try container.encode(storeName, forKey: .storeName)
        try container.encode(addedAt, forKey: .addedAt)
        try container.encode(permission.rawValue, forKey: .permission)
        try container.encodeIfPresent(sharedStoreGroupId, forKey: .sharedStoreGroupId)
        try container.encodeIfPresent(sourceUserStoreId, forKey: .sourceUserStoreId)
        try container.encodeIfPresent(sharedFrom, forKey: .sharedFrom)
        try container.encodeIfPresent(sharedFromName, forKey: .sharedFromName)
        try container.encodeIfPresent(sharedFromEmail, forKey: .sharedFromEmail)
        try container.encodeIfPresent(sharedAt, forKey: .sharedAt)
        try container.encodeIfPresent(sharedWith, forKey: .sharedWith)
        try container.encode(notificationsEnabled, forKey: .notificationsEnabled)
    }
}
