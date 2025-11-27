import Foundation
import FirebaseFirestore

enum StorePermission: String, Codable {
    case owner = "owner"
    case edit = "edit"
    case view = "view"
}

struct UserStore: Codable, Identifiable {
    @DocumentID var id: String? // Firestore document ID - marked with @DocumentID
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

    enum CodingKeys: String, CodingKey {
        // Note: id is excluded from CodingKeys because it's handled by @DocumentID
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
    }

    // Custom decoder to handle missing permission field in existing documents
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        userId = try container.decode(String.self, forKey: .userId)
        storeId = try container.decode(String.self, forKey: .storeId)
        storeName = try container.decode(String.self, forKey: .storeName)
        storeAddress = try container.decode(String.self, forKey: .storeAddress)
        addedAt = try container.decode(TimeInterval.self, forKey: .addedAt)
        latitude = try container.decodeIfPresent(Double.self, forKey: .latitude)
        longitude = try container.decodeIfPresent(Double.self, forKey: .longitude)

        // Default to .owner if permission field is missing (for backward compatibility)
        permission = try container.decodeIfPresent(StorePermission.self, forKey: .permission) ?? .owner

        sharedStoreGroupId = try container.decodeIfPresent(String.self, forKey: .sharedStoreGroupId)
        sourceUserStoreId = try container.decodeIfPresent(String.self, forKey: .sourceUserStoreId)
        sharedFrom = try container.decodeIfPresent(String.self, forKey: .sharedFrom)
        sharedAt = try container.decodeIfPresent(TimeInterval.self, forKey: .sharedAt)
    }
}
