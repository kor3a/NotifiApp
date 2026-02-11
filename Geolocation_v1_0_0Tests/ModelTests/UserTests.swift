//
//  UserTests.swift
//  Geolocation_v1_0_0Tests
//

import XCTest
@testable import Geolocation_v1_0_0

final class UserTests: XCTestCase {

    // MARK: - Codable

    func testCodable_roundTrip() throws {
        let user = User(
            userId: "testuser",
            name: "Test User",
            email: "test@example.com",
            joined: 1700000000.0,
            profilePictureURL: "https://example.com/pic.jpg"
        )
        let data = try JSONEncoder().encode(user)
        let decoded = try JSONDecoder().decode(User.self, from: data)

        XCTAssertEqual(decoded.userId, "testuser")
        XCTAssertEqual(decoded.name, "Test User")
        XCTAssertEqual(decoded.email, "test@example.com")
        XCTAssertEqual(decoded.joined, 1700000000.0)
        XCTAssertEqual(decoded.profilePictureURL, "https://example.com/pic.jpg")
    }

    func testCodable_roundTrip_noProfilePicture() throws {
        let user = User(
            userId: "testuser",
            name: "Test User",
            email: "test@example.com",
            joined: 1700000000.0,
            profilePictureURL: nil
        )
        let data = try JSONEncoder().encode(user)
        let decoded = try JSONDecoder().decode(User.self, from: data)

        XCTAssertNil(decoded.profilePictureURL)
    }

    // MARK: - asDict (Encodable Extension)

    func testAsDict_containsAllFields() {
        let user = User(
            userId: "testuser",
            name: "Test User",
            email: "test@example.com",
            joined: 1700000000.0,
            profilePictureURL: "https://example.com/pic.jpg"
        )
        let dict = user.asDict()

        XCTAssertEqual(dict["userId"] as? String, "testuser")
        XCTAssertEqual(dict["name"] as? String, "Test User")
        XCTAssertEqual(dict["email"] as? String, "test@example.com")
        XCTAssertEqual(dict["joined"] as? Double, 1700000000.0)
        XCTAssertEqual(dict["profilePictureURL"] as? String, "https://example.com/pic.jpg")
    }

    func testAsDict_omitsNilProfilePicture() {
        let user = User(
            userId: "testuser",
            name: "Test User",
            email: "test@example.com",
            joined: 1700000000.0,
            profilePictureURL: nil
        )
        let dict = user.asDict()

        XCTAssertEqual(dict["userId"] as? String, "testuser")
        // profilePictureURL may or may not be in the dict when nil
        // (JSONEncoder omits nil optionals by default, so it should not be present)
        // But JSONSerialization may include NSNull - check both cases
        if let value = dict["profilePictureURL"] {
            XCTAssertTrue(value is NSNull, "Expected profilePictureURL to be NSNull if present")
        }
    }

    // MARK: - Equatable

    func testEquatable_sameUsersAreEqual() {
        let user1 = User(userId: "a", name: "Alice", email: "a@test.com", joined: 0)
        let user2 = User(userId: "a", name: "Alice", email: "a@test.com", joined: 0)
        XCTAssertEqual(user1, user2)
    }

    func testEquatable_differentUsersAreNotEqual() {
        let user1 = User(userId: "a", name: "Alice", email: "a@test.com", joined: 0)
        let user2 = User(userId: "b", name: "Bob", email: "b@test.com", joined: 0)
        XCTAssertNotEqual(user1, user2)
    }

    func testEquatable_differentNamesMakeUnequal() {
        let user1 = User(userId: "a", name: "Alice", email: "a@test.com", joined: 0)
        let user2 = User(userId: "a", name: "Alice Updated", email: "a@test.com", joined: 0)
        XCTAssertNotEqual(user1, user2)
    }
}
