//
//  ReminderTests.swift
//  Geolocation_v1_0_0Tests
//

import XCTest
@testable import Allim

final class ReminderTests: XCTestCase {

    // MARK: - Codable

    func testCodable_roundTrip_basicReminder() throws {
        let reminder = Reminder(
            id: "rem1",
            userStoreId: "us1",
            title: "Buy milk",
            isDone: false,
            createdAt: 1700000000.0
        )
        let data = try JSONEncoder().encode(reminder)
        let decoded = try JSONDecoder().decode(Reminder.self, from: data)

        XCTAssertEqual(decoded.id, "rem1")
        XCTAssertEqual(decoded.userStoreId, "us1")
        XCTAssertEqual(decoded.title, "Buy milk")
        XCTAssertEqual(decoded.isDone, false)
        XCTAssertEqual(decoded.createdAt, 1700000000.0)
        XCTAssertNil(decoded.isShared)
        XCTAssertNil(decoded.sharedFrom)
        XCTAssertNil(decoded.sharedAt)
        XCTAssertNil(decoded.sharedReminderId)
        XCTAssertNil(decoded.sharedWith)
        XCTAssertNil(decoded.photoURLs)
    }

    func testCodable_roundTrip_sharedReminder() throws {
        let reminder = Reminder(
            id: "rem2",
            userStoreId: "us2",
            title: "Buy bread",
            isDone: true,
            createdAt: 1700000000.0,
            isShared: true,
            sharedFrom: "Alice",
            sharedAt: 1700001000.0,
            sharedReminderId: "shared-rem-1",
            sharedWith: ["Bob", "Charlie"]
        )
        let data = try JSONEncoder().encode(reminder)
        let decoded = try JSONDecoder().decode(Reminder.self, from: data)

        XCTAssertEqual(decoded.isShared, true)
        XCTAssertEqual(decoded.sharedFrom, "Alice")
        XCTAssertEqual(decoded.sharedAt, 1700001000.0)
        XCTAssertEqual(decoded.sharedReminderId, "shared-rem-1")
        XCTAssertEqual(decoded.sharedWith, ["Bob", "Charlie"])
    }

    func testCodable_roundTrip_withPhotos() throws {
        let reminder = Reminder(
            id: "rem3",
            userStoreId: "us3",
            title: "Buy eggs",
            isDone: false,
            createdAt: 1700000000.0,
            photoURLs: ["https://example.com/photo1.jpg", "https://example.com/photo2.jpg"]
        )
        let data = try JSONEncoder().encode(reminder)
        let decoded = try JSONDecoder().decode(Reminder.self, from: data)

        XCTAssertEqual(decoded.photoURLs?.count, 2)
        XCTAssertEqual(decoded.photoURLs?[0], "https://example.com/photo1.jpg")
        XCTAssertEqual(decoded.photoURLs?[1], "https://example.com/photo2.jpg")
    }

    // MARK: - Identifiable

    func testIdentifiable_usesFirestoreDocumentId() {
        let reminder = Reminder(
            id: "doc-abc-123",
            userStoreId: "us1",
            title: "Test",
            isDone: false,
            createdAt: 0
        )
        XCTAssertEqual(reminder.id, "doc-abc-123")
    }

    // MARK: - isDone toggle

    func testIsDone_canBeToggled() {
        var reminder = Reminder(
            id: "rem1",
            userStoreId: "us1",
            title: "Test",
            isDone: false,
            createdAt: 0
        )
        XCTAssertFalse(reminder.isDone)
        reminder.isDone = true
        XCTAssertTrue(reminder.isDone)
    }

    // MARK: - Duplicate detection (ReminderViewModel.isDuplicateReminder)

    func testIsDuplicate_exactMatch_returnsTrue() {
        let vm = ReminderViewModel()
        vm.reminders = [
            Reminder(id: "r1", userStoreId: "us1", title: "Buy milk", isDone: false, createdAt: 0)
        ]
        XCTAssertTrue(vm.isDuplicateReminder(title: "Buy milk"))
    }

    func testIsDuplicate_caseInsensitive_returnsTrue() {
        let vm = ReminderViewModel()
        vm.reminders = [
            Reminder(id: "r1", userStoreId: "us1", title: "Buy Milk", isDone: false, createdAt: 0)
        ]
        XCTAssertTrue(vm.isDuplicateReminder(title: "buy milk"))
        XCTAssertTrue(vm.isDuplicateReminder(title: "BUY MILK"))
        XCTAssertTrue(vm.isDuplicateReminder(title: "Buy milk"))
    }

    func testIsDuplicate_leadingTrailingWhitespace_returnsTrue() {
        let vm = ReminderViewModel()
        vm.reminders = [
            Reminder(id: "r1", userStoreId: "us1", title: "Buy milk", isDone: false, createdAt: 0)
        ]
        XCTAssertTrue(vm.isDuplicateReminder(title: "  Buy milk  "))
        XCTAssertTrue(vm.isDuplicateReminder(title: "\nBuy milk\n"))
    }

    func testIsDuplicate_differentTitle_returnsFalse() {
        let vm = ReminderViewModel()
        vm.reminders = [
            Reminder(id: "r1", userStoreId: "us1", title: "Buy milk", isDone: false, createdAt: 0)
        ]
        XCTAssertFalse(vm.isDuplicateReminder(title: "Buy eggs"))
    }

    func testIsDuplicate_emptyList_returnsFalse() {
        let vm = ReminderViewModel()
        vm.reminders = []
        XCTAssertFalse(vm.isDuplicateReminder(title: "Buy milk"))
    }

    func testIsDuplicate_multipleReminders_detectsCorrectly() {
        let vm = ReminderViewModel()
        vm.reminders = [
            Reminder(id: "r1", userStoreId: "us1", title: "Buy milk", isDone: false, createdAt: 0),
            Reminder(id: "r2", userStoreId: "us1", title: "Buy eggs", isDone: false, createdAt: 1),
            Reminder(id: "r3", userStoreId: "us1", title: "Buy bread", isDone: true, createdAt: 2)
        ]
        XCTAssertTrue(vm.isDuplicateReminder(title: "buy EGGS"))
        XCTAssertTrue(vm.isDuplicateReminder(title: "BUY BREAD"))
        XCTAssertFalse(vm.isDuplicateReminder(title: "Buy cheese"))
    }
}
