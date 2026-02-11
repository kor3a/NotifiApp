//
//  SharedStoreGroupTests.swift
//  Geolocation_v1_0_0Tests
//

import XCTest
@testable import Allim

final class SharedStoreGroupTests: XCTestCase {

    // MARK: - Codable

    func testCodable_roundTrip() throws {
        let group = SharedStoreGroup(
            id: "group1",
            storeId: "walmart",
            userStoreIds: ["us1", "us2", "us3"],
            createdAt: 1700000000.0,
            updatedAt: 1700001000.0
        )
        let data = try JSONEncoder().encode(group)
        let decoded = try JSONDecoder().decode(SharedStoreGroup.self, from: data)

        XCTAssertEqual(decoded.id, "group1")
        XCTAssertEqual(decoded.storeId, "walmart")
        XCTAssertEqual(decoded.userStoreIds, ["us1", "us2", "us3"])
        XCTAssertEqual(decoded.createdAt, 1700000000.0)
        XCTAssertEqual(decoded.updatedAt, 1700001000.0)
    }

    // MARK: - Mutability

    func testUserStoreIds_canBeModified() {
        var group = SharedStoreGroup(
            id: "group1",
            storeId: "target",
            userStoreIds: ["us1"],
            createdAt: 0,
            updatedAt: 0
        )
        group.userStoreIds.append("us2")
        XCTAssertEqual(group.userStoreIds, ["us1", "us2"])
    }

    func testUpdatedAt_canBeModified() {
        var group = SharedStoreGroup(
            id: "group1",
            storeId: "target",
            userStoreIds: ["us1"],
            createdAt: 1000,
            updatedAt: 1000
        )
        group.updatedAt = 2000
        XCTAssertEqual(group.updatedAt, 2000)
    }
}
