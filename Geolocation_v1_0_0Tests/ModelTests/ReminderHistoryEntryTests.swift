//
//  ReminderHistoryEntryTests.swift
//  Geolocation_v1_0_0Tests
//

import XCTest
@testable import Allim

final class ReminderHistoryEntryTests: XCTestCase {

    // MARK: - Codable

    func testCodable_roundTrip_basicEntry() throws {
        let entry = ReminderHistoryEntry(
            id: "hist1",
            userStoreId: "us1",
            title: "Buy milk",
            checkedOffAt: 1700000000.0
        )
        let data = try JSONEncoder().encode(entry)
        let decoded = try JSONDecoder().decode(ReminderHistoryEntry.self, from: data)

        XCTAssertEqual(decoded.id, "hist1")
        XCTAssertEqual(decoded.userStoreId, "us1")
        XCTAssertEqual(decoded.title, "Buy milk")
        XCTAssertEqual(decoded.checkedOffAt, 1700000000.0)
        XCTAssertNil(decoded.checkedOffBy)
        XCTAssertNil(decoded.checkedOffById)
        XCTAssertNil(decoded.createdBy)
        XCTAssertNil(decoded.createdById)
        XCTAssertNil(decoded.createdAt)
        XCTAssertNil(decoded.deletedAt)
        XCTAssertNil(decoded.quantity)
        XCTAssertNil(decoded.photoURLs)
        XCTAssertNil(decoded.category)
    }

    func testCodable_roundTrip_fullEntry() throws {
        let entry = ReminderHistoryEntry(
            id: "hist2",
            userStoreId: "us2",
            title: "Buy bread",
            checkedOffAt: 1700002000.0,
            checkedOffBy: "Alice",
            checkedOffById: "alice_id",
            createdBy: "Bob",
            createdById: "bob_id",
            createdAt: 1700000000.0,
            deletedAt: 1700003000.0,
            quantity: 3,
            photoURLs: ["https://example.com/photo1.jpg"],
            category: "Bakery"
        )
        let data = try JSONEncoder().encode(entry)
        let decoded = try JSONDecoder().decode(ReminderHistoryEntry.self, from: data)

        XCTAssertEqual(decoded.checkedOffBy, "Alice")
        XCTAssertEqual(decoded.checkedOffById, "alice_id")
        XCTAssertEqual(decoded.createdBy, "Bob")
        XCTAssertEqual(decoded.createdById, "bob_id")
        XCTAssertEqual(decoded.createdAt, 1700000000.0)
        XCTAssertEqual(decoded.deletedAt, 1700003000.0)
        XCTAssertEqual(decoded.quantity, 3)
        XCTAssertEqual(decoded.photoURLs, ["https://example.com/photo1.jpg"])
        XCTAssertEqual(decoded.category, "Bakery")
    }

    // MARK: - Identifiable

    func testIdentifiable_usesFirestoreDocumentId() {
        let entry = ReminderHistoryEntry(
            id: "history-doc-id",
            userStoreId: "us1",
            title: "Buy eggs",
            checkedOffAt: 1700000000.0
        )
        XCTAssertEqual(entry.id, "history-doc-id")
    }
}
