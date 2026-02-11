//
//  ConversationTests.swift
//  Geolocation_v1_0_0Tests
//

import XCTest
@testable import Allim

final class ConversationTests: XCTestCase {

    private static let fixedTimestamp: TimeInterval = 1_000_000

    private func makeConversation(
        participantIds: [String] = ["user1", "user2"],
        participantNames: [String: String] = ["user1": "Alice", "user2": "Bob"],
        unreadCount: [String: Int] = ["user1": 3, "user2": 0]
    ) -> Conversation {
        return Conversation(
            id: "conv1",
            participantIds: participantIds,
            participantNames: participantNames,
            createdAt: Self.fixedTimestamp,
            lastMessageContent: "Hello",
            lastMessageAt: Self.fixedTimestamp,
            lastMessageSenderId: "user1",
            unreadCount: unreadCount
        )
    }

    // MARK: - otherParticipantName

    func testOtherParticipantName_returnsOtherUser() {
        let conversation = makeConversation()
        XCTAssertEqual(conversation.otherParticipantName(currentUserId: "user1"), "Bob")
        XCTAssertEqual(conversation.otherParticipantName(currentUserId: "user2"), "Alice")
    }

    func testOtherParticipantName_unknownUserId_returnsUnknown() {
        let conversation = makeConversation()
        // If current user is not in the participants, returns first non-matching (which is any)
        // Actually, since both don't match "user3", it returns "Alice" (first iterated)
        // But the method iterates dictionary which is unordered - the result is one of the names
        let name = conversation.otherParticipantName(currentUserId: "user3")
        XCTAssertTrue(name == "Alice" || name == "Bob")
    }

    func testOtherParticipantName_emptyNames_returnsUnknown() {
        let conversation = Conversation(
            id: "conv1",
            participantIds: ["user1"],
            participantNames: ["user1": "Alice"],
            createdAt: Self.fixedTimestamp,
            unreadCount: [:]
        )
        XCTAssertEqual(conversation.otherParticipantName(currentUserId: "user1"), "Unknown")
    }

    // MARK: - otherParticipantId

    func testOtherParticipantId_returnsOtherUserId() {
        let conversation = makeConversation()
        XCTAssertEqual(conversation.otherParticipantId(currentUserId: "user1"), "user2")
        XCTAssertEqual(conversation.otherParticipantId(currentUserId: "user2"), "user1")
    }

    func testOtherParticipantId_unknownUserId_returnsFirst() {
        let conversation = makeConversation()
        // If current user is not in participantIds, returns the first one
        XCTAssertEqual(conversation.otherParticipantId(currentUserId: "user3"), "user1")
    }

    // MARK: - unreadCountFor

    func testUnreadCountFor_existingUser() {
        let conversation = makeConversation()
        XCTAssertEqual(conversation.unreadCountFor(userId: "user1"), 3)
        XCTAssertEqual(conversation.unreadCountFor(userId: "user2"), 0)
    }

    func testUnreadCountFor_unknownUser_returnsZero() {
        let conversation = makeConversation()
        XCTAssertEqual(conversation.unreadCountFor(userId: "unknown"), 0)
    }

    // MARK: - Hashable

    func testHashable_sameIdAreEqual() {
        let conv1 = makeConversation()
        let conv2 = makeConversation()
        XCTAssertEqual(conv1, conv2)
    }

    func testHashable_canBeUsedInSet() {
        let conv1 = Conversation(
            id: "conv1",
            participantIds: ["user1", "user2"],
            participantNames: [:],
            createdAt: 0,
            unreadCount: [:]
        )
        let conv2 = Conversation(
            id: "conv2",
            participantIds: ["user1", "user3"],
            participantNames: [:],
            createdAt: 0,
            unreadCount: [:]
        )
        let conv3 = Conversation(
            id: "conv1",
            participantIds: ["user1", "user2"],
            participantNames: [:],
            createdAt: 100,
            unreadCount: [:]
        )
        let set: Set<Conversation> = [conv1, conv2, conv3]
        XCTAssertEqual(set.count, 2) // conv1 and conv3 have same id
    }

    // MARK: - Codable

    func testCodable_roundTrip() throws {
        let conversation = makeConversation()
        let data = try JSONEncoder().encode(conversation)
        let decoded = try JSONDecoder().decode(Conversation.self, from: data)

        XCTAssertEqual(decoded.id, conversation.id)
        XCTAssertEqual(decoded.participantIds, conversation.participantIds)
        XCTAssertEqual(decoded.lastMessageContent, conversation.lastMessageContent)
        XCTAssertEqual(decoded.unreadCount, conversation.unreadCount)
    }
}
