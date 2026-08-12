//
//  UserStoreTests.swift
//  Geolocation_v1_0_0Tests
//

import XCTest
@testable import Allim

final class UserStoreTests: XCTestCase {

    /// `UserStore` declares `init(from:)`, so there's no memberwise init — build
    /// instances the way the app does, by decoding Firestore data.
    private func makeUserStore(
        id: String?,
        storeName: String = "Whole Foods Market",
        permission: String = "owner",
        sourceUserStoreId: String? = nil,
        sharedStoreGroupId: String? = nil
    ) throws -> UserStore {
        var json: [String: Any] = [
            "userId": "user-1",
            "storeId": Store.normalizedId(from: storeName),
            "storeName": storeName,
            "addedAt": 1_700_000_000.0,
            "permission": permission,
            "notificationsEnabled": true
        ]
        if let sourceUserStoreId = sourceUserStoreId {
            json["sourceUserStoreId"] = sourceUserStoreId
        }
        if let sharedStoreGroupId = sharedStoreGroupId {
            json["sharedStoreGroupId"] = sharedStoreGroupId
        }

        let data = try JSONSerialization.data(withJSONObject: json)
        var userStore = try JSONDecoder().decode(UserStore.self, from: data)
        userStore.id = id
        return userStore
    }

    // MARK: - reminderStoreId

    func testReminderStoreId_owner_usesOwnId() throws {
        let userStore = try makeUserStore(id: "user-store-1", permission: "owner")
        XCTAssertEqual(userStore.reminderStoreId, "user-store-1")
    }

    /// The merge flow (MessagingService) stamps `sourceUserStoreId` onto the
    /// recipient's row while leaving `permission` as `owner`, so the two users can
    /// find each other. The owner still sees only their own reminders, and the
    /// proximity notification must count the same list the UI does.
    func testReminderStoreId_owner_ignoresSourceUserStoreIdFromMergeFlow() throws {
        let userStore = try makeUserStore(
            id: "user-store-1",
            permission: "owner",
            sourceUserStoreId: "senders-user-store-9"
        )
        XCTAssertEqual(userStore.reminderStoreId, "user-store-1")
    }

    func testReminderStoreId_owner_ignoresSharedStoreGroupId() throws {
        let userStore = try makeUserStore(
            id: "user-store-1",
            permission: "owner",
            sharedStoreGroupId: "shared-group-1"
        )
        XCTAssertEqual(userStore.reminderStoreId, "user-store-1")
    }

    func testReminderStoreId_editPermission_usesSharedStoreGroupId() throws {
        let userStore = try makeUserStore(
            id: "user-store-2",
            permission: "edit",
            sharedStoreGroupId: "shared-group-1"
        )
        XCTAssertEqual(userStore.reminderStoreId, "shared-group-1")
    }

    func testReminderStoreId_viewPermission_usesSourceUserStoreId() throws {
        let userStore = try makeUserStore(
            id: "user-store-3",
            permission: "view",
            sourceUserStoreId: "owner-user-store-1"
        )
        XCTAssertEqual(userStore.reminderStoreId, "owner-user-store-1")
    }

    func testReminderStoreId_sourceUserStoreIdTakesPrecedenceOverGroupId() throws {
        let userStore = try makeUserStore(
            id: "user-store-4",
            permission: "view",
            sourceUserStoreId: "owner-store-5",
            sharedStoreGroupId: "shared-group-1"
        )
        XCTAssertEqual(userStore.reminderStoreId, "owner-store-5")
    }

    func testReminderStoreId_recipientFallsBackToOwnIdWhenUnlinked() throws {
        let userStore = try makeUserStore(id: "user-store-6", permission: "view")
        XCTAssertEqual(userStore.reminderStoreId, "user-store-6")
    }

    func testReminderStoreId_isNilWhenDocumentIdMissing() throws {
        let userStore = try makeUserStore(id: nil, permission: "owner")
        XCTAssertNil(userStore.reminderStoreId)
    }

    /// `UserStore.reminderStoreId` and `UserStoreItem.reminderStoreId` are read by
    /// different parts of the app for the same question; they must not drift.
    func testReminderStoreId_matchesUserStoreItemForSamePermissions() throws {
        let cases: [(String, String?, String?)] = [
            ("owner", nil, nil),
            ("owner", "senders-user-store-9", nil),
            ("owner", nil, "shared-group-1"),
            ("edit", nil, "shared-group-1"),
            ("view", "owner-user-store-1", nil),
            ("view", "owner-store-5", "shared-group-1"),
            ("view", nil, nil)
        ]

        for (permission, sourceUserStoreId, sharedStoreGroupId) in cases {
            let userStore = try makeUserStore(
                id: "user-store-x",
                permission: permission,
                sourceUserStoreId: sourceUserStoreId,
                sharedStoreGroupId: sharedStoreGroupId
            )
            let item = UserStoreItem(
                id: "user-store-x",
                store: Store(name: "Whole Foods Market"),
                permission: StorePermission(rawValue: permission) ?? .owner,
                sharedStoreGroupId: sharedStoreGroupId,
                sourceUserStoreId: sourceUserStoreId,
                sharedFromName: nil,
                sharedFromId: nil,
                sharedWith: nil,
                notificationsEnabled: true
            )

            XCTAssertEqual(
                userStore.reminderStoreId,
                item.reminderStoreId,
                "Mismatch for permission=\(permission) source=\(sourceUserStoreId ?? "nil") group=\(sharedStoreGroupId ?? "nil")"
            )
        }
    }
}
