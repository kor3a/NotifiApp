//
//  FriendshipTests.swift
//  Geolocation_v1_0_0Tests
//

import XCTest
@testable import Allim

final class FriendshipTests: XCTestCase {

    private func makeFriendship() -> Friendship {
        return Friendship(
            id: "friendship1",
            requesterId: "alice",
            requesterName: "Alice Smith",
            requesterEmail: "alice@example.com",
            requesterProfilePictureURL: "https://example.com/alice.jpg",
            receiverId: "bob",
            receiverName: "Bob Jones",
            receiverEmail: "bob@example.com",
            receiverProfilePictureURL: "https://example.com/bob.jpg",
            status: .accepted,
            createdAt: Date().timeIntervalSince1970,
            acceptedAt: Date().timeIntervalSince1970
        )
    }

    // MARK: - isRequester

    func testIsRequester_trueForRequester() {
        let friendship = makeFriendship()
        XCTAssertTrue(friendship.isRequester(currentUserId: "alice"))
    }

    func testIsRequester_falseForReceiver() {
        let friendship = makeFriendship()
        XCTAssertFalse(friendship.isRequester(currentUserId: "bob"))
    }

    func testIsRequester_falseForUnknownUser() {
        let friendship = makeFriendship()
        XCTAssertFalse(friendship.isRequester(currentUserId: "charlie"))
    }

    // MARK: - friendId

    func testFriendId_returnsReceiverId_whenCurrentIsRequester() {
        let friendship = makeFriendship()
        XCTAssertEqual(friendship.friendId(currentUserId: "alice"), "bob")
    }

    func testFriendId_returnsRequesterId_whenCurrentIsReceiver() {
        let friendship = makeFriendship()
        XCTAssertEqual(friendship.friendId(currentUserId: "bob"), "alice")
    }

    // MARK: - friendName

    func testFriendName_returnsReceiverName_whenCurrentIsRequester() {
        let friendship = makeFriendship()
        XCTAssertEqual(friendship.friendName(currentUserId: "alice"), "Bob Jones")
    }

    func testFriendName_returnsRequesterName_whenCurrentIsReceiver() {
        let friendship = makeFriendship()
        XCTAssertEqual(friendship.friendName(currentUserId: "bob"), "Alice Smith")
    }

    // MARK: - friendEmail

    func testFriendEmail_returnsReceiverEmail_whenCurrentIsRequester() {
        let friendship = makeFriendship()
        XCTAssertEqual(friendship.friendEmail(currentUserId: "alice"), "bob@example.com")
    }

    func testFriendEmail_returnsRequesterEmail_whenCurrentIsReceiver() {
        let friendship = makeFriendship()
        XCTAssertEqual(friendship.friendEmail(currentUserId: "bob"), "alice@example.com")
    }

    // MARK: - friendProfilePictureURL

    func testFriendProfilePictureURL_returnsReceiverURL_whenCurrentIsRequester() {
        let friendship = makeFriendship()
        XCTAssertEqual(friendship.friendProfilePictureURL(currentUserId: "alice"), "https://example.com/bob.jpg")
    }

    func testFriendProfilePictureURL_returnsRequesterURL_whenCurrentIsReceiver() {
        let friendship = makeFriendship()
        XCTAssertEqual(friendship.friendProfilePictureURL(currentUserId: "bob"), "https://example.com/alice.jpg")
    }

    func testFriendProfilePictureURL_nilWhenFriendHasNone() {
        let friendship = Friendship(
            id: "f1",
            requesterId: "alice",
            requesterName: "Alice",
            requesterEmail: "alice@example.com",
            requesterProfilePictureURL: nil,
            receiverId: "bob",
            receiverName: "Bob",
            receiverEmail: "bob@example.com",
            receiverProfilePictureURL: nil,
            status: .accepted,
            createdAt: 0,
            acceptedAt: nil
        )
        XCTAssertNil(friendship.friendProfilePictureURL(currentUserId: "alice"))
        XCTAssertNil(friendship.friendProfilePictureURL(currentUserId: "bob"))
    }

    // MARK: - toContact

    func testToContact_fromRequesterPerspective() {
        let friendship = makeFriendship()
        let contact = friendship.toContact(currentUserId: "alice")

        XCTAssertEqual(contact.id, "bob")
        XCTAssertEqual(contact.name, "Bob Jones")
        XCTAssertEqual(contact.email, "bob@example.com")
        XCTAssertEqual(contact.profilePictureURL, "https://example.com/bob.jpg")
    }

    func testToContact_fromReceiverPerspective() {
        let friendship = makeFriendship()
        let contact = friendship.toContact(currentUserId: "bob")

        XCTAssertEqual(contact.id, "alice")
        XCTAssertEqual(contact.name, "Alice Smith")
        XCTAssertEqual(contact.email, "alice@example.com")
        XCTAssertEqual(contact.profilePictureURL, "https://example.com/alice.jpg")
    }

    // MARK: - Codable

    func testCodable_roundTrip() throws {
        let friendship = makeFriendship()
        let data = try JSONEncoder().encode(friendship)
        let decoded = try JSONDecoder().decode(Friendship.self, from: data)

        XCTAssertEqual(decoded.id, friendship.id)
        XCTAssertEqual(decoded.requesterId, friendship.requesterId)
        XCTAssertEqual(decoded.receiverId, friendship.receiverId)
        XCTAssertEqual(decoded.status, friendship.status)
        XCTAssertEqual(decoded.requesterProfilePictureURL, friendship.requesterProfilePictureURL)
    }

    // MARK: - FriendshipStatus

    func testFriendshipStatus_rawValues() {
        XCTAssertEqual(FriendshipStatus.pending.rawValue, "pending")
        XCTAssertEqual(FriendshipStatus.accepted.rawValue, "accepted")
        XCTAssertEqual(FriendshipStatus.rejected.rawValue, "rejected")
    }
}
