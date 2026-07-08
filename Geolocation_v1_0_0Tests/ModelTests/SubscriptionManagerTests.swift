//
//  SubscriptionManagerTests.swift
//  Geolocation_v1_0_0Tests
//
//  Unit tests for subscription isolation logic.
//  These cover the pure static helpers on SubscriptionManager that decide
//  whether a StoreKit entitlement belongs to the current app user.
//

import XCTest
@testable import Allim

final class SubscriptionManagerTests: XCTestCase {

    // MARK: - User.subscriptionToken (new field)

    func testUser_subscriptionToken_roundTrip() throws {
        let token = UUID().uuidString
        let user = User(
            userId: "testuser",
            name: "Test",
            email: "test@example.com",
            joined: 0,
            subscriptionToken: token
        )
        let data = try JSONEncoder().encode(user)
        let decoded = try JSONDecoder().decode(User.self, from: data)
        XCTAssertEqual(decoded.subscriptionToken, token)
    }

    func testUser_subscriptionToken_nilByDefault() {
        let user = User(userId: "u", name: "N", email: "e@test.com", joined: 0)
        XCTAssertNil(user.subscriptionToken)
    }

    func testUser_asDict_includesSubscriptionToken() {
        let token = UUID().uuidString
        let user = User(
            userId: "testuser",
            name: "Test",
            email: "test@example.com",
            joined: 0,
            subscriptionToken: token
        )
        let dict = user.asDict()
        XCTAssertEqual(dict["subscriptionToken"] as? String, token)
    }

    func testUser_asDict_omitsNilSubscriptionToken() {
        let user = User(userId: "u", name: "N", email: "e@test.com", joined: 0)
        let dict = user.asDict()
        if let value = dict["subscriptionToken"] {
            XCTAssertTrue(value is NSNull,
                "Expected subscriptionToken to be NSNull when nil, got \(type(of: value))")
        }
        // Key simply absent is also acceptable
    }

    // MARK: - transactionTokenBelongsToUser

    func testTokenMatching_matchingTokensAllowSubscription() {
        let token = UUID()
        XCTAssertTrue(
            SubscriptionManager.transactionTokenBelongsToUser(
                transactionToken: token,
                userToken: token
            )
        )
    }

    func testTokenMatching_mismatchedTokensDenySubscription() {
        XCTAssertFalse(
            SubscriptionManager.transactionTokenBelongsToUser(
                transactionToken: UUID(),
                userToken: UUID()
            )
        )
    }

    func testTokenMatching_nilTransactionTokenIsLegacyAndAllowed() {
        // Legacy purchases recorded before appAccountToken was introduced have no
        // token. They pass through and rely on Firestore's isSubscribed as the gate.
        XCTAssertTrue(
            SubscriptionManager.transactionTokenBelongsToUser(
                transactionToken: nil,
                userToken: UUID()
            )
        )
    }

    func testTokenMatching_nilTransactionTokenAllowedEvenWithNoUserToken() {
        // Existing user who signed up before subscriptionToken was stored
        XCTAssertTrue(
            SubscriptionManager.transactionTokenBelongsToUser(
                transactionToken: nil,
                userToken: nil
            )
        )
    }

    func testTokenMatching_transactionHasTokenButNoCurrentUser() {
        // A renewal arrives while no user is logged in (or for a different user
        // who has no token yet) — deny it.
        XCTAssertFalse(
            SubscriptionManager.transactionTokenBelongsToUser(
                transactionToken: UUID(),
                userToken: nil
            )
        )
    }

    // MARK: - shouldQueryStoreKit

    func testShouldQueryStoreKit_subscribedUserQueriesStoreKit() {
        let user = User(userId: "a", name: "A", email: "a@test.com", joined: 0, isSubscribed: true)
        XCTAssertTrue(SubscriptionManager.shouldQueryStoreKit(for: user))
    }

    func testShouldQueryStoreKit_adminSubscribedUserQueriesStoreKit() {
        let user = User(userId: "a", name: "A", email: "a@test.com", joined: 0, adminSubscribed: true)
        XCTAssertTrue(SubscriptionManager.shouldQueryStoreKit(for: user))
    }

    func testShouldQueryStoreKit_explicitlyUnsubscribedUserSkipsStoreKit() {
        let user = User(userId: "a", name: "A", email: "a@test.com", joined: 0, isSubscribed: false)
        XCTAssertFalse(SubscriptionManager.shouldQueryStoreKit(for: user))
    }

    func testShouldQueryStoreKit_nilSubscriptionFieldSkipsStoreKit() {
        // New users or users whose record pre-dates the isSubscribed field
        let user = User(userId: "a", name: "A", email: "a@test.com", joined: 0)
        XCTAssertFalse(SubscriptionManager.shouldQueryStoreKit(for: user))
    }

    func testShouldQueryStoreKit_bothFalseSkipsStoreKit() {
        let user = User(
            userId: "a", name: "A", email: "a@test.com", joined: 0,
            isSubscribed: false, adminSubscribed: false
        )
        XCTAssertFalse(SubscriptionManager.shouldQueryStoreKit(for: user))
    }

    func testShouldQueryStoreKit_adminOverrideAloneIsEnough() {
        // adminSubscribed=true with isSubscribed=false should still query StoreKit
        // (to populate activeProductID for the management view, even though
        // adminSubscribed users won't have a StoreKit entitlement).
        let user = User(
            userId: "a", name: "A", email: "a@test.com", joined: 0,
            isSubscribed: false, adminSubscribed: true
        )
        XCTAssertTrue(SubscriptionManager.shouldQueryStoreKit(for: user))
    }

    // MARK: - Free Tier Limits (canAddStore)

    func testCanAddStore_freeUserUnderLimit() {
        XCTAssertTrue(SubscriptionManager.canAddStore(isSubscribed: false, currentStoreCount: 0))
        XCTAssertTrue(SubscriptionManager.canAddStore(
            isSubscribed: false,
            currentStoreCount: SubscriptionManager.freeStoreLimit - 1
        ))
    }

    func testCanAddStore_freeUserAtLimitIsBlocked() {
        XCTAssertFalse(SubscriptionManager.canAddStore(
            isSubscribed: false,
            currentStoreCount: SubscriptionManager.freeStoreLimit
        ))
    }

    func testCanAddStore_grandfatheredFreeUserOverLimitIsBlockedFromAddingMore() {
        // A user who had 10 stores before the limit existed keeps them all,
        // but adding an 11th requires a subscription.
        XCTAssertFalse(SubscriptionManager.canAddStore(isSubscribed: false, currentStoreCount: 10))
    }

    func testCanAddStore_subscriberIsUnlimited() {
        XCTAssertTrue(SubscriptionManager.canAddStore(isSubscribed: true, currentStoreCount: 0))
        XCTAssertTrue(SubscriptionManager.canAddStore(
            isSubscribed: true,
            currentStoreCount: SubscriptionManager.freeStoreLimit
        ))
        XCTAssertTrue(SubscriptionManager.canAddStore(isSubscribed: true, currentStoreCount: 500))
    }

    // MARK: - Free Tier Limits (canAddReminder)

    func testCanAddReminder_freeUserUnderLimit() {
        XCTAssertTrue(SubscriptionManager.canAddReminder(isSubscribed: false, currentReminderCount: 0))
        XCTAssertTrue(SubscriptionManager.canAddReminder(
            isSubscribed: false,
            currentReminderCount: SubscriptionManager.freeReminderLimitPerStore - 1
        ))
    }

    func testCanAddReminder_freeUserAtLimitIsBlocked() {
        XCTAssertFalse(SubscriptionManager.canAddReminder(
            isSubscribed: false,
            currentReminderCount: SubscriptionManager.freeReminderLimitPerStore
        ))
    }

    func testCanAddReminder_grandfatheredFreeUserOverLimitIsBlockedFromAddingMore() {
        // A store that had 20 items before the limit existed keeps them all,
        // but adding a 21st requires a subscription.
        XCTAssertFalse(SubscriptionManager.canAddReminder(isSubscribed: false, currentReminderCount: 20))
    }

    func testCanAddReminder_subscriberIsUnlimited() {
        XCTAssertTrue(SubscriptionManager.canAddReminder(isSubscribed: true, currentReminderCount: 0))
        XCTAssertTrue(SubscriptionManager.canAddReminder(
            isSubscribed: true,
            currentReminderCount: SubscriptionManager.freeReminderLimitPerStore
        ))
        XCTAssertTrue(SubscriptionManager.canAddReminder(isSubscribed: true, currentReminderCount: 500))
    }
}
