//
//  KeychainStoreTests.swift
//  Geolocation_v1_0_0Tests
//

import XCTest
@testable import Allim

/// Exercises the keychain wrapper membership cards rely on to survive the app
/// being deleted. The tests run against the real keychain under a throwaway
/// service name, and skip themselves where the keychain isn't usable (an
/// unsigned test run, for instance) rather than failing the suite.
final class KeychainStoreTests: XCTestCase {

    private var store: KeychainStore!

    override func setUpWithError() throws {
        try super.setUpWithError()
        store = KeychainStore(service: "com.kor3a.nearbuy.tests.\(UUID().uuidString)")
        do {
            try store.set(Data("probe".utf8), account: "probe")
            try store.removeItem(account: "probe")
        } catch {
            throw XCTSkip("Keychain unavailable in this environment: \(error.localizedDescription)")
        }
    }

    override func tearDownWithError() throws {
        for account in (try? store.accounts()) ?? [] {
            try? store.removeItem(account: account)
        }
        store = nil
        try super.tearDownWithError()
    }

    func testReadingAnAccountThatWasNeverWrittenReturnsNil() throws {
        XCTAssertNil(try store.data(account: "missing"))
    }

    func testRoundTrip() throws {
        let payload = Data("1234 5678 9012".utf8)
        try store.set(payload, account: "cards.metadata")

        XCTAssertEqual(try store.data(account: "cards.metadata"), payload)
    }

    func testSetReplacesAnExistingValue() throws {
        try store.set(Data("first".utf8), account: "cards.metadata")
        try store.set(Data("second".utf8), account: "cards.metadata")

        XCTAssertEqual(try store.data(account: "cards.metadata"), Data("second".utf8))
    }

    func testAccountsAreScopedToTheService() throws {
        let other = KeychainStore(service: "com.kor3a.nearbuy.tests.\(UUID().uuidString)")
        try store.set(Data("mine".utf8), account: "photo.a.jpg")
        try other.set(Data("theirs".utf8), account: "photo.b.jpg")
        defer { try? other.removeItem(account: "photo.b.jpg") }

        XCTAssertEqual(try store.accounts(), ["photo.a.jpg"])
        XCTAssertNil(try store.data(account: "photo.b.jpg"))
    }

    func testAccountsListsEveryStoredItem() throws {
        try store.set(Data("a".utf8), account: "cards.metadata")
        try store.set(Data("b".utf8), account: "photo.a.jpg")
        try store.set(Data("c".utf8), account: "photo.b.jpg")

        XCTAssertEqual(
            Set(try store.accounts()),
            ["cards.metadata", "photo.a.jpg", "photo.b.jpg"]
        )
    }

    func testRemoveItemDeletesTheValue() throws {
        try store.set(Data("gone soon".utf8), account: "cards.metadata")
        try store.removeItem(account: "cards.metadata")

        XCTAssertNil(try store.data(account: "cards.metadata"))
    }

    func testRemovingSomethingThatIsNotThereSucceeds() throws {
        XCTAssertNoThrow(try store.removeItem(account: "never-written"))
    }

    func testStoresDataLargeEnoughForACardPhoto() throws {
        let photo = Data(repeating: 0xAB, count: 600_000)
        try store.set(photo, account: "photo.big.jpg")

        XCTAssertEqual(try store.data(account: "photo.big.jpg")?.count, photo.count)
    }
}
