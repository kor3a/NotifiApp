//
//  MessageTests.swift
//  Geolocation_v1_0_0Tests
//

import XCTest
@testable import Geolocation_v1_0_0

final class MessageTests: XCTestCase {

    // MARK: - Message Codable

    func testMessage_codable_roundTrip() throws {
        let message = Message(
            id: "msg1",
            conversationId: "conv1",
            senderId: "alice",
            senderName: "Alice",
            content: "Hello!",
            createdAt: 1700000000.0,
            isRead: false,
            linkedReminder: nil,
            linkedStore: nil
        )
        let data = try JSONEncoder().encode(message)
        let decoded = try JSONDecoder().decode(Message.self, from: data)

        XCTAssertEqual(decoded.id, "msg1")
        XCTAssertEqual(decoded.conversationId, "conv1")
        XCTAssertEqual(decoded.senderId, "alice")
        XCTAssertEqual(decoded.senderName, "Alice")
        XCTAssertEqual(decoded.content, "Hello!")
        XCTAssertFalse(decoded.isRead)
        XCTAssertNil(decoded.linkedReminder)
        XCTAssertNil(decoded.linkedStore)
    }

    func testMessage_codable_withLinkedReminder() throws {
        let linked = LinkedReminder(
            reminderTitle: "Buy milk",
            storeName: "Walmart",
            storeAddress: "123 Main St",
            reminderId: "rem1",
            storeId: "walmart",
            senderUserId: "alice",
            status: .pending,
            storeLatitude: 37.7749,
            storeLongitude: -122.4194,
            storeImageURL: nil
        )
        let message = Message(
            id: "msg2",
            conversationId: "conv1",
            senderId: "alice",
            senderName: "Alice",
            content: "Shared a reminder",
            createdAt: 1700000000.0,
            isRead: true,
            linkedReminder: linked,
            linkedStore: nil
        )
        let data = try JSONEncoder().encode(message)
        let decoded = try JSONDecoder().decode(Message.self, from: data)

        XCTAssertEqual(decoded.linkedReminder?.reminderTitle, "Buy milk")
        XCTAssertEqual(decoded.linkedReminder?.storeName, "Walmart")
        XCTAssertEqual(decoded.linkedReminder?.status, .pending)
    }

    func testMessage_codable_withLinkedStore() throws {
        let linked = LinkedStore(
            storeName: "Target",
            storeAddress: "456 Oak Ave",
            storeId: "target",
            senderUserId: "bob",
            senderUserStoreId: "us-bob-target",
            senderEmail: "bob@example.com",
            status: .pending,
            permission: "edit",
            storeLatitude: 37.0,
            storeLongitude: -122.0,
            storeImageURL: nil,
            reminderTitles: ["Buy soap", "Get towels"]
        )
        let message = Message(
            id: "msg3",
            conversationId: "conv1",
            senderId: "bob",
            senderName: "Bob",
            content: "Shared a store",
            createdAt: 1700000000.0,
            isRead: false,
            linkedReminder: nil,
            linkedStore: linked
        )
        let data = try JSONEncoder().encode(message)
        let decoded = try JSONDecoder().decode(Message.self, from: data)

        XCTAssertEqual(decoded.linkedStore?.storeName, "Target")
        XCTAssertEqual(decoded.linkedStore?.permission, "edit")
        XCTAssertEqual(decoded.linkedStore?.reminderTitles?.count, 2)
    }

    // MARK: - LinkedReminder

    func testLinkedReminder_codable_roundTrip() throws {
        let linked = LinkedReminder(
            reminderTitle: "Buy eggs",
            storeName: "Costco",
            storeAddress: nil,
            reminderId: nil,
            storeId: nil,
            senderUserId: nil,
            status: .accepted,
            storeLatitude: nil,
            storeLongitude: nil,
            storeImageURL: nil
        )
        let data = try JSONEncoder().encode(linked)
        let decoded = try JSONDecoder().decode(LinkedReminder.self, from: data)

        XCTAssertEqual(decoded.reminderTitle, "Buy eggs")
        XCTAssertEqual(decoded.storeName, "Costco")
        XCTAssertNil(decoded.storeAddress)
        XCTAssertEqual(decoded.status, .accepted)
    }

    // MARK: - LinkedStore

    func testLinkedStore_codable_roundTrip() throws {
        let linked = LinkedStore(
            storeName: "Walmart",
            storeAddress: "789 Pine St",
            storeId: "walmart",
            senderUserId: "alice",
            permission: "view"
        )
        let data = try JSONEncoder().encode(linked)
        let decoded = try JSONDecoder().decode(LinkedStore.self, from: data)

        XCTAssertEqual(decoded.storeName, "Walmart")
        XCTAssertEqual(decoded.permission, "view")
        XCTAssertEqual(decoded.status, .pending) // default
    }

    // MARK: - SharedReminderStatus

    func testSharedReminderStatus_rawValues() {
        XCTAssertEqual(SharedReminderStatus.pending.rawValue, "pending")
        XCTAssertEqual(SharedReminderStatus.accepted.rawValue, "accepted")
        XCTAssertEqual(SharedReminderStatus.rejected.rawValue, "rejected")
    }

    // MARK: - Contact

    func testContact_identifiable() {
        let contact = Contact(id: "user1", name: "Alice", email: "alice@example.com", profilePictureURL: nil)
        XCTAssertEqual(contact.id, "user1")
    }

    func testContact_equatable() {
        let c1 = Contact(id: "user1", name: "Alice", email: "alice@example.com", profilePictureURL: nil)
        let c2 = Contact(id: "user1", name: "Alice", email: "alice@example.com", profilePictureURL: nil)
        XCTAssertEqual(c1, c2)
    }
}
