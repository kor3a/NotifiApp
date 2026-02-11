//
//  StorePermissionTests.swift
//  Geolocation_v1_0_0Tests
//

import XCTest
@testable import Allim

final class StorePermissionTests: XCTestCase {

    func testRawValues() {
        XCTAssertEqual(StorePermission.owner.rawValue, "owner")
        XCTAssertEqual(StorePermission.edit.rawValue, "edit")
        XCTAssertEqual(StorePermission.view.rawValue, "view")
    }

    func testInitFromRawValue() {
        XCTAssertEqual(StorePermission(rawValue: "owner"), .owner)
        XCTAssertEqual(StorePermission(rawValue: "edit"), .edit)
        XCTAssertEqual(StorePermission(rawValue: "view"), .view)
        XCTAssertNil(StorePermission(rawValue: "admin"))
        XCTAssertNil(StorePermission(rawValue: ""))
    }

    func testCodable_roundTrip() throws {
        let permissions: [StorePermission] = [.owner, .edit, .view]
        let data = try JSONEncoder().encode(permissions)
        let decoded = try JSONDecoder().decode([StorePermission].self, from: data)
        XCTAssertEqual(decoded, permissions)
    }

    func testCodable_decodesFromString() throws {
        let json = "\"edit\"".data(using: .utf8)!
        let decoded = try JSONDecoder().decode(StorePermission.self, from: json)
        XCTAssertEqual(decoded, .edit)
    }
}
