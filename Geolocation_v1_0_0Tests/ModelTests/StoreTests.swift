//
//  StoreTests.swift
//  Geolocation_v1_0_0Tests
//

import XCTest
@testable import Allim

final class StoreTests: XCTestCase {

    // MARK: - normalizedId Tests

    func testNormalizedId_lowercases() {
        XCTAssertEqual(Store.normalizedId(from: "Walmart"), "walmart")
        XCTAssertEqual(Store.normalizedId(from: "TARGET"), "target")
    }

    func testNormalizedId_replacesSpacesWithDashes() {
        XCTAssertEqual(Store.normalizedId(from: "Trader Joes"), "trader-joes")
        XCTAssertEqual(Store.normalizedId(from: "Whole Foods Market"), "whole-foods-market")
    }

    func testNormalizedId_removesApostrophes() {
        XCTAssertEqual(Store.normalizedId(from: "Trader Joe's"), "trader-joes")
        XCTAssertEqual(Store.normalizedId(from: "McDonald's"), "mcdonalds")
    }

    func testNormalizedId_removesPeriods() {
        XCTAssertEqual(Store.normalizedId(from: "H.E.B."), "heb")
    }

    func testNormalizedId_removesCommas() {
        XCTAssertEqual(Store.normalizedId(from: "Bed, Bath & Beyond"), "bed-bath-and-beyond")
    }

    func testNormalizedId_replacesAmpersandWithAnd() {
        XCTAssertEqual(Store.normalizedId(from: "Barnes & Noble"), "barnes-and-noble")
        XCTAssertEqual(Store.normalizedId(from: "Bed Bath & Beyond"), "bed-bath-and-beyond")
    }

    func testNormalizedId_trimsWhitespace() {
        XCTAssertEqual(Store.normalizedId(from: "  Walmart  "), "walmart")
        XCTAssertEqual(Store.normalizedId(from: "\n Target \n"), "target")
    }

    func testNormalizedId_combinedTransformations() {
        XCTAssertEqual(
            Store.normalizedId(from: "  Trader Joe's & Co.  "),
            "trader-joes-and-co"
        )
    }

    func testNormalizedId_emptyString() {
        XCTAssertEqual(Store.normalizedId(from: ""), "")
    }

    func testNormalizedId_sameChainProducesSameId() {
        // Different capitalizations of the same store should produce the same ID
        let id1 = Store.normalizedId(from: "Walmart")
        let id2 = Store.normalizedId(from: "walmart")
        let id3 = Store.normalizedId(from: "WALMART")
        XCTAssertEqual(id1, id2)
        XCTAssertEqual(id2, id3)
    }

    // MARK: - Init Tests

    func testInit_fromName_setsNormalizedId() {
        let store = Store(name: "Trader Joe's")
        XCTAssertEqual(store.id, "trader-joes")
        XCTAssertEqual(store.name, "Trader Joe's")
        XCTAssertEqual(store.reminderCount, 0)
        XCTAssertNil(store.sortOrder)
        XCTAssertNil(store.imageURL)
    }

    func testInit_fromName_withOptionalFields() {
        let store = Store(name: "Target", reminderCount: 5, sortOrder: 2, imageURL: "https://example.com/img.jpg")
        XCTAssertEqual(store.id, "target")
        XCTAssertEqual(store.reminderCount, 5)
        XCTAssertEqual(store.sortOrder, 2)
        XCTAssertEqual(store.imageURL, "https://example.com/img.jpg")
    }

    func testInit_withExplicitId() {
        let store = Store(id: "custom-id", name: "Custom Store")
        XCTAssertEqual(store.id, "custom-id")
        XCTAssertEqual(store.name, "Custom Store")
    }

    // MARK: - Codable Tests

    func testCodable_roundTrip() throws {
        let store = Store(name: "Walmart", reminderCount: 3, sortOrder: 1, imageURL: "https://example.com/walmart.jpg")
        let data = try JSONEncoder().encode(store)
        let decoded = try JSONDecoder().decode(Store.self, from: data)

        XCTAssertEqual(decoded.id, store.id)
        XCTAssertEqual(decoded.name, store.name)
        XCTAssertEqual(decoded.reminderCount, store.reminderCount)
        XCTAssertEqual(decoded.sortOrder, store.sortOrder)
        XCTAssertEqual(decoded.imageURL, store.imageURL)
    }

    func testCodable_roundTrip_nilOptionals() throws {
        let store = Store(name: "Target")
        let data = try JSONEncoder().encode(store)
        let decoded = try JSONDecoder().decode(Store.self, from: data)

        XCTAssertEqual(decoded.id, store.id)
        XCTAssertEqual(decoded.name, store.name)
    }

    // MARK: - Hashable Tests

    func testHashable_sameIdAreEqual() {
        let store1 = Store(id: "walmart", name: "Walmart")
        let store2 = Store(id: "walmart", name: "Walmart")
        XCTAssertEqual(store1, store2)
    }

    func testHashable_differentIdAreNotEqual() {
        let store1 = Store(id: "walmart", name: "Walmart")
        let store2 = Store(id: "target", name: "Target")
        XCTAssertNotEqual(store1, store2)
    }

    func testHashable_canBeUsedInSet() {
        let store1 = Store(name: "Walmart")
        let store2 = Store(name: "Walmart")
        let store3 = Store(name: "Target")
        let set: Set<Store> = [store1, store2, store3]
        XCTAssertEqual(set.count, 2)
    }
}
