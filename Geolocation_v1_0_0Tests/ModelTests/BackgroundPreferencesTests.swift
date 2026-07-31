//
//  BackgroundPreferencesTests.swift
//  Geolocation_v1_0_0Tests
//
//  Unit tests for per-screen background storage.
//

import XCTest
import SwiftUI
@testable import Allim

final class BackgroundPreferencesTests: XCTestCase {

    private var suiteName: String!
    private var defaults: UserDefaults!
    private var preferences: BackgroundPreferences!

    override func setUpWithError() throws {
        suiteName = "BackgroundPreferencesTests.\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        preferences = BackgroundPreferences(defaults: defaults)
    }

    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: suiteName)
        preferences = nil
        defaults = nil
        suiteName = nil
    }

    // MARK: - Defaults

    func testBackgroundColor_defaultsToSystem() {
        XCTAssertEqual(preferences.backgroundColor(for: .stores), .system)
        XCTAssertEqual(preferences.backgroundColor(for: .reminders), .system)
        XCTAssertEqual(preferences.backgroundColor(for: .conversation(id: "abc")), .system)
    }

    func testBackgroundColor_unknownStoredValue_fallsBackToSystem() {
        defaults.set("chartreuse", forKey: BackgroundSurface.stores.colorStorageKey)
        XCTAssertEqual(preferences.backgroundColor(for: .stores), .system)
    }

    // MARK: - Persistence

    func testSetBackgroundColor_persistsAcrossInstances() {
        preferences.setBackgroundColor(.ocean, for: .stores)

        let reloaded = BackgroundPreferences(defaults: defaults)
        XCTAssertEqual(reloaded.backgroundColor(for: .stores), .ocean)
    }

    func testSetBackgroundColor_isIsolatedPerSurface() {
        preferences.setBackgroundColor(.ocean, for: .stores)
        preferences.setBackgroundColor(.sand, for: .reminders)

        XCTAssertEqual(preferences.backgroundColor(for: .stores), .ocean)
        XCTAssertEqual(preferences.backgroundColor(for: .reminders), .sand)
    }

    func testSetBackgroundColor_isIsolatedPerConversation() {
        preferences.setBackgroundColor(.plum, for: .conversation(id: "chat-1"))

        XCTAssertEqual(preferences.backgroundColor(for: .conversation(id: "chat-1")), .plum)
        XCTAssertEqual(preferences.backgroundColor(for: .conversation(id: "chat-2")), .system)
    }

    func testSetBackgroundColor_systemClearsStoredValue() {
        preferences.setBackgroundColor(.forest, for: .stores)
        preferences.setBackgroundColor(.system, for: .stores)

        XCTAssertEqual(preferences.backgroundColor(for: .stores), .system)
        XCTAssertNil(defaults.string(forKey: BackgroundSurface.stores.colorStorageKey))
    }

    // MARK: - Reset

    func testResetAll_clearsEverySurfaceIncludingConversations() {
        preferences.setBackgroundColor(.ocean, for: .stores)
        preferences.setBackgroundColor(.sand, for: .reminders)
        preferences.setBackgroundColor(.plum, for: .conversation(id: "chat-1"))

        preferences.resetAll()

        XCTAssertEqual(preferences.backgroundColor(for: .stores), .system)
        XCTAssertEqual(preferences.backgroundColor(for: .reminders), .system)
        XCTAssertEqual(preferences.backgroundColor(for: .conversation(id: "chat-1")), .system)
    }

    // MARK: - Palette

    func testSelectableColors_excludesSystemAndCoversPalette() {
        XCTAssertFalse(AppBackgroundColor.selectableColors.contains(.system))
        XCTAssertEqual(AppBackgroundColor.selectableColors.count, AppBackgroundColor.allCases.count - 1)
    }

    func testStorageKeys_areUniquePerSurface() {
        let keys = [
            BackgroundSurface.stores.colorStorageKey,
            BackgroundSurface.reminders.colorStorageKey,
            BackgroundSurface.conversation(id: "chat-1").colorStorageKey,
            BackgroundSurface.conversation(id: "chat-2").colorStorageKey
        ]
        XCTAssertEqual(Set(keys).count, keys.count)
    }

    /// Light and dark variants must actually differ, otherwise a color that
    /// reads well in one appearance would wash out in the other.
    func testFill_differsBetweenLightAndDark() {
        for color in AppBackgroundColor.allCases {
            XCTAssertNotEqual(
                color.fill(for: .light),
                color.fill(for: .dark),
                "\(color.displayName) uses the same fill in light and dark mode"
            )
        }
    }
}
