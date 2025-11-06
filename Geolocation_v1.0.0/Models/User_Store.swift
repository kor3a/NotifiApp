import Foundation

struct UserStore: Codable, Identifiable {
    var id: String // Firestore document ID
    let userId: String
    let storeId: String
    let storeName: String // Denormalized for easier display
    let storeAddress: String // Denormalized for easier display
    let addedAt: TimeInterval

    enum CodingKeys: String, CodingKey {
        case id
        case userId
        case storeId
        case storeName
        case storeAddress
        case addedAt
    }
}
