//
//  FriendRequestTests.swift
//  Geolocation_v1_0_0Tests
//

import XCTest
@testable import Allim

final class FriendRequestTests: XCTestCase {

    // MARK: - Codable

    func testCodable_roundTrip() throws {
        let request = FriendRequest(
            id: "req1",
            fromUserId: "alice",
            toUserId: "bob",
            fromUserName: "Alice Smith",
            toUserName: "Bob Jones",
            fromUserEmail: "alice@example.com",
            toUserEmail: "bob@example.com",
            status: .pending,
            createdAt: 1700000000.0,
            fromUserProfilePictureURL: "https://example.com/alice.jpg",
            toUserProfilePictureURL: nil
        )
        let data = try JSONEncoder().encode(request)
        let decoded = try JSONDecoder().decode(FriendRequest.self, from: data)

        XCTAssertEqual(decoded.id, "req1")
        XCTAssertEqual(decoded.fromUserId, "alice")
        XCTAssertEqual(decoded.toUserId, "bob")
        XCTAssertEqual(decoded.fromUserName, "Alice Smith")
        XCTAssertEqual(decoded.toUserName, "Bob Jones")
        XCTAssertEqual(decoded.fromUserEmail, "alice@example.com")
        XCTAssertEqual(decoded.toUserEmail, "bob@example.com")
        XCTAssertEqual(decoded.status, .pending)
        XCTAssertEqual(decoded.fromUserProfilePictureURL, "https://example.com/alice.jpg")
        XCTAssertNil(decoded.toUserProfilePictureURL)
    }

    // MARK: - FriendRequestStatus

    func testFriendRequestStatus_rawValues() {
        XCTAssertEqual(FriendRequestStatus.pending.rawValue, "pending")
        XCTAssertEqual(FriendRequestStatus.accepted.rawValue, "accepted")
        XCTAssertEqual(FriendRequestStatus.rejected.rawValue, "rejected")
    }

    func testFriendRequestStatus_decodable() throws {
        let json = """
        "accepted"
        """.data(using: .utf8)!
        let status = try JSONDecoder().decode(FriendRequestStatus.self, from: json)
        XCTAssertEqual(status, .accepted)
    }

    // MARK: - Equatable

    func testEquatable_sameRequestsAreEqual() {
        let req1 = FriendRequest(
            id: "req1", fromUserId: "a", toUserId: "b",
            fromUserName: "A", toUserName: "B",
            fromUserEmail: "a@test.com", toUserEmail: "b@test.com",
            status: .pending, createdAt: 0,
            fromUserProfilePictureURL: nil, toUserProfilePictureURL: nil
        )
        let req2 = FriendRequest(
            id: "req1", fromUserId: "a", toUserId: "b",
            fromUserName: "A", toUserName: "B",
            fromUserEmail: "a@test.com", toUserEmail: "b@test.com",
            status: .pending, createdAt: 0,
            fromUserProfilePictureURL: nil, toUserProfilePictureURL: nil
        )
        XCTAssertEqual(req1, req2)
    }

    // MARK: - Status mutation

    func testStatus_canBeMutated() {
        var request = FriendRequest(
            id: "req1", fromUserId: "a", toUserId: "b",
            fromUserName: "A", toUserName: "B",
            fromUserEmail: "a@test.com", toUserEmail: "b@test.com",
            status: .pending, createdAt: 0,
            fromUserProfilePictureURL: nil, toUserProfilePictureURL: nil
        )
        XCTAssertEqual(request.status, .pending)

        request.status = .accepted
        XCTAssertEqual(request.status, .accepted)

        request.status = .rejected
        XCTAssertEqual(request.status, .rejected)
    }
}
