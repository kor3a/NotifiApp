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
        XCTAssertNil(decoded.isOutOfStock)
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

    // MARK: - isOutOfStock

    func testCodable_roundTrip_outOfStock() throws {
        let reminder = Reminder(
            id: "rem_oos",
            userStoreId: "us1",
            title: "Buy avocados",
            isDone: false,
            createdAt: 1700000000.0,
            isOutOfStock: true
        )
        let data = try JSONEncoder().encode(reminder)
        let decoded = try JSONDecoder().decode(Reminder.self, from: data)

        XCTAssertEqual(decoded.isOutOfStock, true)
        XCTAssertEqual(decoded.isDone, false)
    }

    func testCodable_roundTrip_outOfStockNil() throws {
        let reminder = Reminder(
            id: "rem_oos2",
            userStoreId: "us1",
            title: "Buy bananas",
            isDone: false,
            createdAt: 1700000000.0
        )
        let data = try JSONEncoder().encode(reminder)
        let decoded = try JSONDecoder().decode(Reminder.self, from: data)

        XCTAssertNil(decoded.isOutOfStock)
    }

    func testIsOutOfStock_canBeToggled() {
        var reminder = Reminder(
            id: "rem1",
            userStoreId: "us1",
            title: "Test",
            isDone: false,
            createdAt: 0
        )
        XCTAssertNil(reminder.isOutOfStock)
        reminder.isOutOfStock = true
        XCTAssertEqual(reminder.isOutOfStock, true)
        reminder.isOutOfStock = false
        XCTAssertEqual(reminder.isOutOfStock, false)
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

    // MARK: - Last-edit attribution (model)

    func testCodable_roundTrip_lastEditedFields() throws {
        let reminder = Reminder(
            id: "rem-edited",
            userStoreId: "us1",
            title: "Buy oat milk",
            isDone: false,
            createdAt: 1700000000.0,
            isShared: true,
            sharedFrom: "Bob",
            sharedFromId: "bob_id",
            lastEditedAt: 1700005000.0,
            lastEditedBy: "Alice",
            lastEditedById: "alice_id"
        )
        let data = try JSONEncoder().encode(reminder)
        let decoded = try JSONDecoder().decode(Reminder.self, from: data)

        // The author is preserved — an edit records who edited, it doesn't
        // rewrite who created the item.
        XCTAssertEqual(decoded.sharedFrom, "Bob")
        XCTAssertEqual(decoded.sharedFromId, "bob_id")
        XCTAssertEqual(decoded.lastEditedAt, 1700005000.0)
        XCTAssertEqual(decoded.lastEditedBy, "Alice")
        XCTAssertEqual(decoded.lastEditedById, "alice_id")
    }

    func testCodable_roundTrip_unedited_hasNoEditStamp() throws {
        let reminder = Reminder(
            id: "rem-fresh",
            userStoreId: "us1",
            title: "Buy milk",
            isDone: false,
            createdAt: 1700000000.0
        )
        let data = try JSONEncoder().encode(reminder)
        let decoded = try JSONDecoder().decode(Reminder.self, from: data)

        XCTAssertNil(decoded.lastEditedAt)
        XCTAssertNil(decoded.lastEditedBy)
        XCTAssertNil(decoded.lastEditedById)
    }

    // MARK: - Which member the row's avatar names

    func testAttributedParticipant_neverEdited_namesAuthor() {
        let participant = SharedAvatarPalette.attributedParticipant(
            sharedFrom: "Bob",
            sharedFromId: "bob_id",
            lastEditedBy: nil,
            lastEditedById: nil
        )
        XCTAssertEqual(participant.id, "bob_id")
        XCTAssertEqual(participant.name, "Bob")
    }

    func testAttributedParticipant_editedByOtherMember_namesEditor() {
        // Bob created it, Alice edited it — the row becomes Alice's.
        let participant = SharedAvatarPalette.attributedParticipant(
            sharedFrom: "Bob",
            sharedFromId: "bob_id",
            lastEditedBy: "Alice",
            lastEditedById: "alice_id"
        )
        XCTAssertEqual(participant.id, "alice_id")
        XCTAssertEqual(participant.name, "Alice")
    }

    func testAttributedParticipant_editorIdOnly_recoversNameFromMembers() {
        let participant = SharedAvatarPalette.attributedParticipant(
            sharedFrom: "Bob",
            sharedFromId: "bob_id",
            lastEditedBy: nil,
            lastEditedById: "alice_id",
            memberNames: ["alice_id": "Alice", "bob_id": "Bob"]
        )
        XCTAssertEqual(participant.id, "alice_id")
        XCTAssertEqual(participant.name, "Alice")
    }

    func testAttributedParticipant_unnamedEditor_fallsBackToAuthor() {
        // An edit stamp we can't put a name to must not blank the row.
        let participant = SharedAvatarPalette.attributedParticipant(
            sharedFrom: "Bob",
            sharedFromId: "bob_id",
            lastEditedBy: nil,
            lastEditedById: "stranger_id"
        )
        XCTAssertEqual(participant.id, "bob_id")
        XCTAssertEqual(participant.name, "Bob")
    }

    func testAttributedParticipant_noAttributionAtAll_isEmpty() {
        let participant = SharedAvatarPalette.attributedParticipant(
            sharedFrom: nil,
            sharedFromId: nil,
            lastEditedBy: nil,
            lastEditedById: nil
        )
        XCTAssertNil(participant.id)
        XCTAssertNil(participant.name)
    }

    func testParticipantIdentity_authorAndEditor_getDistinctColorKeys() {
        let author = SharedAvatarPalette.participantIdentity(
            name: "Bob",
            id: "bob_id",
            currentUserName: "Carol",
            currentUserId: "carol_id"
        )
        let editor = SharedAvatarPalette.participantIdentity(
            name: "Alice",
            id: "alice_id",
            currentUserName: "Carol",
            currentUserId: "carol_id"
        )
        XCTAssertEqual(author?.name, "Bob")
        XCTAssertEqual(editor?.name, "Alice")
        XCTAssertNotEqual(author?.key, editor?.key)
    }

    func testParticipantIdentity_currentUserAsEditor_usesTheirOwnIdentity() {
        let identity = SharedAvatarPalette.participantIdentity(
            name: "Alice",
            id: "alice_id",
            currentUserName: "Alice",
            currentUserId: "alice_id"
        )
        XCTAssertEqual(identity?.name, "Alice")
        XCTAssertEqual(identity?.key, SharedAvatarPalette.identityKey(id: "alice_id", name: "Alice"))
    }

    // MARK: - Stamping an edit (ReminderEditAttribution)

    private func withSignedInUser(_ user: User?, _ body: () -> Void) {
        let previous = UserSessionManager.shared.currentUser
        UserSessionManager.shared.currentUser = user
        body()
        UserSessionManager.shared.currentUser = previous
    }

    private func makeUser(id: String, name: String) -> User {
        User(
            userId: id,
            name: name,
            email: "\(id)@example.com",
            joined: 1700000000.0,
            profilePictureURL: nil
        )
    }

    func testStampFields_signedInUser_recordsWhoAndWhen() {
        withSignedInUser(makeUser(id: "alice_id", name: "Alice")) {
            let fields = ReminderEditAttribution.stampFields(
                now: Date(timeIntervalSince1970: 1700005000.0)
            )
            XCTAssertEqual(fields["lastEditedBy"] as? String, "Alice")
            XCTAssertEqual(fields["lastEditedById"] as? String, "alice_id")
            XCTAssertEqual(fields["lastEditedAt"] as? TimeInterval, 1700005000.0)
        }
    }

    func testStampFields_noSignedInUser_stampsNothing() {
        // Nobody to credit — better to leave the previous stamp standing than to
        // half-overwrite it.
        withSignedInUser(nil) {
            XCTAssertTrue(ReminderEditAttribution.stampFields().isEmpty)
        }
    }

    func testStamped_keepsTheEditItselfAndAddsAttribution() {
        withSignedInUser(makeUser(id: "alice_id", name: "Alice")) {
            let fields = ReminderEditAttribution.stamped(["title": "Buy oat milk"])
            XCTAssertEqual(fields["title"] as? String, "Buy oat milk")
            XCTAssertEqual(fields["lastEditedBy"] as? String, "Alice")
            XCTAssertEqual(fields["lastEditedById"] as? String, "alice_id")
        }
    }

    func testStamped_doesNotOverwriteAnExplicitAttribution() {
        withSignedInUser(makeUser(id: "alice_id", name: "Alice")) {
            let fields = ReminderEditAttribution.stamped([
                "title": "Buy oat milk",
                "lastEditedBy": "Bob"
            ])
            XCTAssertEqual(fields["lastEditedBy"] as? String, "Bob")
        }
    }
}
