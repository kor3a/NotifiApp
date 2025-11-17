import Foundation

struct UserStore: Codable, Identifiable {
    var id: String // Firestore document ID
    let userId: String
    let storeId: String
    let storeName: String // Denormalized for easier display
    let storeAddress: String // Denormalized for easier display
    let addedAt: TimeInterval
    var latitude: Double? = nil // Denormalized for location monitoring
    var longitude: Double? = nil // Denormalized for location monitoring

    enum CodingKeys: String, CodingKey {
        case id
        case userId
        case storeId
        case storeName
        case storeAddress
        case addedAt
        case latitude
        case longitude
    }
}
