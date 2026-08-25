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

    // MARK: - Access level labelling

    /// Regression: the shared-store sheet used to label anything that wasn't `.edit` as
    /// "View Only", so a store that had been merged with an incoming share — which keeps
    /// `.owner` — showed "Shared by <name> · View Only" while the user could still edit it.
    func testCanEdit_onlyViewIsReadOnly() {
        XCTAssertTrue(StorePermission.owner.canEdit)
        XCTAssertTrue(StorePermission.edit.canEdit)
        XCTAssertFalse(StorePermission.view.canEdit)
    }

    func testDisplayLabel_matchesEditability() {
        XCTAssertEqual(StorePermission.owner.displayLabel, "Can Edit")
        XCTAssertEqual(StorePermission.edit.displayLabel, "Can Edit")
        XCTAssertEqual(StorePermission.view.displayLabel, "View Only")
    }

    func testCodable_decodesFromString() throws {
        let json = "\"edit\"".data(using: .utf8)!
        let decoded = try JSONDecoder().decode(StorePermission.self, from: json)
        XCTAssertEqual(decoded, .edit)
    }
}
