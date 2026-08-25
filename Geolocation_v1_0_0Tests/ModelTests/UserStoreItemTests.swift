//
//  UserStoreItemTests.swift
//  Geolocation_v1_0_0Tests
//

import XCTest
@testable import Allim

final class UserStoreItemTests: XCTestCase {

    // MARK: - reminderStoreId

    func testReminderStoreId_owner_usesOwnId() {
        let item = UserStoreItem(
            id: "user-store-1",
            store: Store(name: "Walmart"),
            permission: .owner,
            sharedStoreGroupId: nil,
            sourceUserStoreId: nil,
            sharedFromName: nil,
            sharedFromId: nil,
            sharedWith: nil,
            notificationsEnabled: true
        )
        XCTAssertEqual(item.reminderStoreId, "user-store-1")
    }

    func testReminderStoreId_editPermission_usesSharedStoreGroupId() {
        let item = UserStoreItem(
            id: "user-store-2",
            store: Store(name: "Target"),
            permission: .edit,
            sharedStoreGroupId: "shared-group-1",
            sourceUserStoreId: nil,
            sharedFromName: "Alice",
            sharedFromId: "user-alice-123",
            sharedWith: nil,
            notificationsEnabled: true
        )
        XCTAssertEqual(item.reminderStoreId, "shared-group-1")
    }

    func testReminderStoreId_viewPermission_usesSourceUserStoreId() {
        let item = UserStoreItem(
            id: "user-store-3",
            store: Store(name: "Costco"),
            permission: .view,
            sharedStoreGroupId: nil,
            sourceUserStoreId: "owner-user-store-1",
            sharedFromName: "Bob",
            sharedFromId: "user-bob-456",
            sharedWith: nil,
            notificationsEnabled: true
        )
        XCTAssertEqual(item.reminderStoreId, "owner-user-store-1")
    }

    func testReminderStoreId_sourceUserStoreIdTakesPrecedence() {
        // When both sourceUserStoreId and sharedStoreGroupId are set,
        // sourceUserStoreId takes precedence (it's checked first with ??)
        let item = UserStoreItem(
            id: "user-store-4",
            store: Store(name: "Costco"),
            permission: .view,
            sharedStoreGroupId: "shared-group-2",
            sourceUserStoreId: "owner-store-5",
            sharedFromName: "Charlie",
            sharedFromId: "user-charlie-789",
            sharedWith: nil,
            notificationsEnabled: true
        )
        XCTAssertEqual(item.reminderStoreId, "owner-store-5")
    }

    // MARK: - Merged stores

    /// A store the user owned and then merged into someone else's shared list becomes a
    /// live `.edit` participant on that list, so its reminders come from the source store.
    /// Before the merge produced a real link, this store stayed `.owner` and kept reading
    /// its own reminders — which is why items either side added afterwards never crossed.
    func testReminderStoreId_mergedFromOwnStore_readsTheSharedList() {
        let item = UserStoreItem(
            id: "my-target-store",
            store: Store(name: "Target"),
            permission: .edit,
            sharedStoreGroupId: nil,
            sourceUserStoreId: "leahs-target-store",
            sharedFromName: "Leah",
            sharedFromId: "user-leah-1",
            sharedWith: ["Leah"],
            notificationsEnabled: true,
            mergedFromOwnStore: true
        )
        XCTAssertEqual(item.reminderStoreId, "leahs-target-store")
        XCTAssertTrue(item.permission.canEdit)
        XCTAssertEqual(item.permission.displayLabel, "Can Edit")
    }

    func testMergedFromOwnStore_defaultsToFalse() {
        let item = UserStoreItem(
            id: "user-store-9",
            store: Store(name: "Target"),
            permission: .owner,
            sharedStoreGroupId: nil,
            sourceUserStoreId: nil,
            sharedFromName: nil,
            sharedFromId: nil,
            sharedWith: nil,
            notificationsEnabled: true
        )
        XCTAssertFalse(item.mergedFromOwnStore)
    }

    // MARK: - Identifiable / Hashable

    func testIdentifiable_usesUserStoreDocumentId() {
        let item = UserStoreItem(
            id: "doc-abc",
            store: Store(name: "Walmart"),
            permission: .owner,
            sharedStoreGroupId: nil,
            sourceUserStoreId: nil,
            sharedFromName: nil,
            sharedFromId: nil,
            sharedWith: nil,
            notificationsEnabled: true
        )
        XCTAssertEqual(item.id, "doc-abc")
    }

    func testHashable_sameIdProducesSameHash() {
        let item1 = UserStoreItem(
            id: "doc-1",
            store: Store(name: "Walmart"),
            permission: .owner,
            sharedStoreGroupId: nil,
            sourceUserStoreId: nil,
            sharedFromName: nil,
            sharedFromId: nil,
            sharedWith: nil,
            notificationsEnabled: true
        )
        let item2 = UserStoreItem(
            id: "doc-1",
            store: Store(name: "Walmart"),
            permission: .owner,
            sharedStoreGroupId: nil,
            sourceUserStoreId: nil,
            sharedFromName: nil,
            sharedFromId: nil,
            sharedWith: nil,
            notificationsEnabled: true
        )
        XCTAssertEqual(item1.hashValue, item2.hashValue)
    }

    // MARK: - Notifications

    func testNotificationsEnabled_default() {
        let item = UserStoreItem(
            id: "doc-1",
            store: Store(name: "Target"),
            permission: .owner,
            sharedStoreGroupId: nil,
            sourceUserStoreId: nil,
            sharedFromName: nil,
            sharedFromId: nil,
            sharedWith: nil,
            notificationsEnabled: true
        )
        XCTAssertTrue(item.notificationsEnabled)
    }

    func testNotificationsDisabled() {
        let item = UserStoreItem(
            id: "doc-1",
            store: Store(name: "Target"),
            permission: .owner,
            sharedStoreGroupId: nil,
            sourceUserStoreId: nil,
            sharedFromName: nil,
            sharedFromId: nil,
            sharedWith: nil,
            notificationsEnabled: false
        )
        XCTAssertFalse(item.notificationsEnabled)
    }
}
