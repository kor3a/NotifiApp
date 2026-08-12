//
//  StoreNameMatchingTests.swift
//  Geolocation_v1_0_0Tests
//

import XCTest
@testable import Allim

/// Covers the name test that decides whether a MapKit search result is the store
/// the user saved. Too strict and the store never gets geofenced at all; too loose
/// and the user gets notified at unrelated places.
final class StoreNameMatchingTests: XCTestCase {

    private func matches(_ saved: String, _ mapKitResult: String) -> Bool {
        LocationMonitoringManager.storeNamesMatch(
            Store.normalizedId(from: saved),
            Store.normalizedId(from: mapKitResult)
        )
    }

    func testExactNameMatches() {
        XCTAssertTrue(matches("Albertsons", "Albertsons"))
        XCTAssertTrue(matches("99 Ranch Market", "99 Ranch Market"))
    }

    func testPunctuationAndCaseAreIgnored() {
        XCTAssertTrue(matches("Trader Joe's", "trader joes"))
        XCTAssertTrue(matches("H-Mart", "H Mart"))
    }

    /// MapKit commonly qualifies a chain with its branch or city.
    func testBranchQualifiedResultMatchesSavedName() {
        XCTAssertTrue(matches("H Mart", "H Mart Rancho Cucamonga"))
        XCTAssertTrue(matches("Albertsons", "Albertsons Market"))
        XCTAssertTrue(matches("Target", "Target Optical"))
    }

    /// And the reverse: a saved name that is itself the longer form.
    func testSavedNameLongerThanResultMatches() {
        XCTAssertTrue(matches("99 Ranch Market", "99 Ranch"))
        XCTAssertTrue(matches("Starbucks Coffee Company", "Starbucks"))
    }

    func testUnrelatedStoresDoNotMatch() {
        XCTAssertFalse(matches("Albertsons", "Vons"))
        XCTAssertFalse(matches("H Mart", "Walmart"))
        XCTAssertFalse(matches("Target", "Trader Joe's"))
        XCTAssertFalse(matches("Sprouts Farmers Market", "Whole Foods Market"))
    }

    /// A shared suffix is not a match — only a shared beginning is.
    func testSharedSuffixDoesNotMatch() {
        XCTAssertFalse(matches("H Mart", "Super Mart"))
        XCTAssertFalse(matches("99 Ranch Market", "Ranch Market"))
    }

    func testEmptyNameNeverMatches() {
        XCTAssertFalse(matches("Albertsons", ""))
        XCTAssertFalse(matches("", "Albertsons"))
    }
}
