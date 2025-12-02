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
    let storeId: String
    let storeName: String // Denormalized for easier display
    let storeAddress: String // Denormalized for easier display
    let addedAt: TimeInterval
    var latitude: Double? = nil // Denormalized for location monitoring
    var longitude: Double? = nil // Denormalized for location monitoring
    var permission: StorePermission = .owner // Default to owner for existing stores
    var sharedStoreGroupId: String? = nil // Links co-owners for Can Edit permission
    var sourceUserStoreId: String? = nil // For View Only: points to owner's user_store ID for fetching reminders
    var sharedFrom: String? = nil // Email of user who shared
    var sharedAt: TimeInterval? = nil // When it was shared
    var notificationsEnabled: Bool = true // Whether notifications are enabled for this store

    enum CodingKeys: String, CodingKey {
        // Note: id is excluded from CodingKeys and set manually from doc.documentID
        case userId
        case storeId
        case storeName
        case storeAddress
        case addedAt
        case latitude
        case longitude
        case permission
        case sharedStoreGroupId
        case sourceUserStoreId
        case sharedFrom
        case sharedAt
        case notificationsEnabled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userId = try container.decode(String.self, forKey: .userId)
        storeId = try container.decode(String.self, forKey: .storeId)
        storeName = try container.decode(String.self, forKey: .storeName)
        storeAddress = try container.decode(String.self, forKey: .storeAddress)
        addedAt = try container.decode(TimeInterval.self, forKey: .addedAt)
        latitude = try container.decodeIfPresent(Double.self, forKey: .latitude)
        longitude = try container.decodeIfPresent(Double.self, forKey: .longitude)
        sharedStoreGroupId = try container.decodeIfPresent(String.self, forKey: .sharedStoreGroupId)
        sourceUserStoreId = try container.decodeIfPresent(String.self, forKey: .sourceUserStoreId)
        sharedFrom = try container.decodeIfPresent(String.self, forKey: .sharedFrom)
        sharedAt = try container.decodeIfPresent(TimeInterval.self, forKey: .sharedAt)

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
        try container.encode(storeAddress, forKey: .storeAddress)
        try container.encode(addedAt, forKey: .addedAt)
        try container.encodeIfPresent(latitude, forKey: .latitude)
        try container.encodeIfPresent(longitude, forKey: .longitude)
        try container.encode(permission.rawValue, forKey: .permission)
        try container.encodeIfPresent(sharedStoreGroupId, forKey: .sharedStoreGroupId)
        try container.encodeIfPresent(sourceUserStoreId, forKey: .sourceUserStoreId)
        try container.encodeIfPresent(sharedFrom, forKey: .sharedFrom)
        try container.encodeIfPresent(sharedAt, forKey: .sharedAt)
        try container.encode(notificationsEnabled, forKey: .notificationsEnabled)
    }
}
