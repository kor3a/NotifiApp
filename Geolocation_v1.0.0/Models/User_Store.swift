import Foundation

struct UserStore: Codable, Identifiable {
    let id: UUID
    let userId: String
    let storeId: String
    let addedAt: TimeInterval
}
