import Foundation

enum StorePermission: String, Codable {
    case owner = "owner"
    case edit = "edit"
    case view = "view"
}

struct UserStore: Codable, Identifiable {
    var id: String // Firestore document ID
    let userId: String
    let storeId: String
    let storeName: String // Denormalized for easier display
    let storeAddress: String // Denormalized for easier display
    let addedAt: TimeInterval
    var latitude: Double? = nil // Denormalized for location monitoring
    var longitude: Double? = nil // Denormalized for location monitoring
    var permission: StorePermission = .owner // Default to owner for existing stores
    var sharedStoreGroupId: String? = nil // Links co-owners for Can Edit permission
    var sharedFrom: String? = nil // Email of user who shared
    var sharedAt: TimeInterval? = nil // When it was shared

    enum CodingKeys: String, CodingKey {
        case id
        case userId
        case storeId
        case storeName
        case storeAddress
        case addedAt
        case latitude
        case longitude
        case permission
        case sharedStoreGroupId
        case sharedFrom
        case sharedAt
    }
}
