//
//  BackgroundPreferencesTests.swift
//  Geolocation_v1_0_0Tests
//
//  Unit tests for per-screen background storage.
//

import XCTest
import SwiftUI
import UIKit
@testable import Allim

final class BackgroundPreferencesTests: XCTestCase {

    private var suiteName: String!
    private var defaults: UserDefaults!
    private var imageDirectory: URL!
    private var preferences: BackgroundPreferences!

    override func setUpWithError() throws {
        suiteName = "BackgroundPreferencesTests.\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        imageDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("BackgroundPreferencesTests-\(UUID().uuidString)", isDirectory: true)
        preferences = BackgroundPreferences(defaults: defaults, imageDirectory: imageDirectory)
    }

    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: imageDirectory)
        preferences = nil
        defaults = nil
        imageDirectory = nil
        suiteName = nil
    }

    // MARK: - Helpers

    /// A solid-color JPEG of the requested size, standing in for a photo pick.
    private func sampleImageData(width: CGFloat, height: CGFloat, color: UIColor = .systemBlue) throws -> Data {
        let size = CGSize(width: width, height: height)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        return try XCTUnwrap(image.jpegData(compressionQuality: 1.0))
    }

    // MARK: - Color Defaults

    func testBackgroundColor_defaultsToSystem() {
        XCTAssertEqual(preferences.backgroundColor(for: .stores), .system)
        XCTAssertEqual(preferences.backgroundColor(for: .reminders(storeId: "store-1")), .system)
        XCTAssertEqual(preferences.backgroundColor(for: .conversation(id: "abc")), .system)
    }

    func testBackgroundColor_unknownStoredValue_fallsBackToSystem() {
        defaults.set("chartreuse", forKey: BackgroundSurface.stores.colorStorageKey)
        XCTAssertEqual(preferences.backgroundColor(for: .stores), .system)
    }

    // MARK: - Color Persistence

    func testSetBackgroundColor_persistsAcrossInstances() {
        preferences.setBackgroundColor(.ocean, for: .stores)

        let reloaded = BackgroundPreferences(defaults: defaults, imageDirectory: imageDirectory)
        XCTAssertEqual(reloaded.backgroundColor(for: .stores), .ocean)
    }

    func testSetBackgroundColor_isIsolatedPerSurface() {
        preferences.setBackgroundColor(.ocean, for: .stores)
        preferences.setBackgroundColor(.sand, for: .reminders(storeId: "store-1"))

        XCTAssertEqual(preferences.backgroundColor(for: .stores), .ocean)
        XCTAssertEqual(preferences.backgroundColor(for: .reminders(storeId: "store-1")), .sand)
    }

    func testSetBackgroundColor_isIsolatedPerStore() {
        preferences.setBackgroundColor(.teal, for: .reminders(storeId: "store-1"))

        XCTAssertEqual(preferences.backgroundColor(for: .reminders(storeId: "store-1")), .teal)
        XCTAssertEqual(preferences.backgroundColor(for: .reminders(storeId: "store-2")), .system)
    }

    /// A store and a conversation that happen to share an id are still
    /// different surfaces and must not read each other's background.
    func testSurfaces_withMatchingIds_doNotCollide() throws {
        let data = try sampleImageData(width: 300, height: 300)
        preferences.setBackgroundColor(.rose, for: .reminders(storeId: "shared-id"))
        preferences.setBackgroundImage(from: data, for: .conversation(id: "shared-id"))

        XCTAssertEqual(preferences.backgroundColor(for: .reminders(storeId: "shared-id")), .rose)
        XCTAssertFalse(preferences.hasBackgroundImage(for: .reminders(storeId: "shared-id")))
        XCTAssertTrue(preferences.hasBackgroundImage(for: .conversation(id: "shared-id")))
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

    // MARK: - Photos

    func testSetBackgroundImage_persistsAcrossInstances() throws {
        let data = try sampleImageData(width: 400, height: 600)
        XCTAssertTrue(preferences.setBackgroundImage(from: data, for: .stores))

        let reloaded = BackgroundPreferences(defaults: defaults, imageDirectory: imageDirectory)
        XCTAssertNotNil(reloaded.backgroundImage(for: .stores))
    }

    func testSetBackgroundImage_isIsolatedPerSurface() throws {
        let data = try sampleImageData(width: 300, height: 300)
        preferences.setBackgroundImage(from: data, for: .stores)

        XCTAssertTrue(preferences.hasBackgroundImage(for: .stores))
        XCTAssertFalse(preferences.hasBackgroundImage(for: .reminders(storeId: "store-1")))
    }

    /// Stores and Reminders are separate screens: a photo on one must not
    /// disturb the other's color, and vice versa.
    func testStoresAndReminders_doNotShareState() throws {
        let data = try sampleImageData(width: 300, height: 300)
        preferences.setBackgroundImage(from: data, for: .stores)
        preferences.setDimLevel(0.55, for: .stores)
        preferences.setBackgroundColor(.forest, for: .reminders(storeId: "store-1"))

        XCTAssertTrue(preferences.hasBackgroundImage(for: .stores))
        XCTAssertEqual(preferences.backgroundColor(for: .stores), .system)
        XCTAssertEqual(preferences.dimLevel(for: .stores), 0.55)

        XCTAssertFalse(preferences.hasBackgroundImage(for: .reminders(storeId: "store-1")))
        XCTAssertEqual(preferences.backgroundColor(for: .reminders(storeId: "store-1")), .forest)
        XCTAssertEqual(preferences.dimLevel(for: .reminders(storeId: "store-1")), BackgroundPreferences.defaultDimLevel)
    }

    func testSetBackgroundImage_rejectsNonImageData() {
        let garbage = Data("not an image".utf8)
        XCTAssertFalse(preferences.setBackgroundImage(from: garbage, for: .stores))
        XCTAssertFalse(preferences.hasBackgroundImage(for: .stores))
    }

    func testRemoveBackgroundImage_clearsPhotoAndDim() throws {
        let data = try sampleImageData(width: 300, height: 300)
        preferences.setBackgroundImage(from: data, for: .stores)
        preferences.setDimLevel(0.6, for: .stores)

        preferences.removeBackgroundImage(for: .stores)

        XCTAssertFalse(preferences.hasBackgroundImage(for: .stores))
        XCTAssertEqual(preferences.dimLevel(for: .stores), BackgroundPreferences.defaultDimLevel)
    }

    /// A photo and a color are mutually exclusive — whichever was picked last wins.
    func testPhotoAndColor_areMutuallyExclusive() throws {
        let data = try sampleImageData(width: 300, height: 300)

        preferences.setBackgroundColor(.ocean, for: .stores)
        preferences.setBackgroundImage(from: data, for: .stores)
        XCTAssertTrue(preferences.hasBackgroundImage(for: .stores))
        XCTAssertEqual(preferences.backgroundColor(for: .stores), .system)

        preferences.setBackgroundColor(.sand, for: .stores)
        XCTAssertFalse(preferences.hasBackgroundImage(for: .stores))
        XCTAssertEqual(preferences.backgroundColor(for: .stores), .sand)
    }

    // MARK: - Downscaling

    func testDownscaled_shrinksOversizedImagesToBudget() throws {
        let original = try XCTUnwrap(UIImage(data: try sampleImageData(width: 4000, height: 2000)))
        let scaled = try XCTUnwrap(BackgroundPreferences.downscaled(original, maxDimension: 1600))

        XCTAssertEqual(scaled.size.width, 1600, accuracy: 1)
        XCTAssertEqual(scaled.size.height, 800, accuracy: 1)
    }

    func testDownscaled_leavesSmallImagesUntouched() throws {
        let original = try XCTUnwrap(UIImage(data: try sampleImageData(width: 600, height: 400)))
        let scaled = try XCTUnwrap(BackgroundPreferences.downscaled(original, maxDimension: 1600))

        XCTAssertEqual(scaled.size.width, 600, accuracy: 1)
        XCTAssertEqual(scaled.size.height, 400, accuracy: 1)
    }

    func testPreparedImageData_returnsNilForNonImageData() {
        XCTAssertNil(BackgroundPreferences.preparedImageData(from: Data("nope".utf8)))
    }

    // MARK: - Dimming

    func testDimLevel_defaultsAndClamps() {
        XCTAssertEqual(preferences.dimLevel(for: .stores), BackgroundPreferences.defaultDimLevel)

        preferences.setDimLevel(-1, for: .stores)
        XCTAssertEqual(preferences.dimLevel(for: .stores), 0)

        preferences.setDimLevel(5, for: .stores)
        XCTAssertEqual(preferences.dimLevel(for: .stores), BackgroundPreferences.maxDimLevel)
    }

    func testDimLevel_zeroIsDistinctFromUnset() {
        preferences.setDimLevel(0, for: .stores)
        XCTAssertEqual(preferences.dimLevel(for: .stores), 0)
    }

    // MARK: - Reset

    func testReset_clearsOnlyTheGivenSurface() throws {
        let data = try sampleImageData(width: 300, height: 300)
        preferences.setBackgroundImage(from: data, for: .stores)
        preferences.setBackgroundColor(.sand, for: .reminders(storeId: "store-1"))

        preferences.reset(.stores)

        XCTAssertFalse(preferences.hasBackgroundImage(for: .stores))
        XCTAssertEqual(preferences.backgroundColor(for: .reminders(storeId: "store-1")), .sand)
    }

    func testResetAll_clearsEverySurfaceIncludingConversationsAndPhotos() throws {
        let data = try sampleImageData(width: 300, height: 300)
        preferences.setBackgroundColor(.ocean, for: .stores)
        preferences.setBackgroundColor(.sand, for: .reminders(storeId: "store-1"))
        preferences.setBackgroundColor(.plum, for: .conversation(id: "chat-1"))
        preferences.setBackgroundImage(from: data, for: .conversation(id: "chat-2"))
        preferences.setDimLevel(0.7, for: .conversation(id: "chat-2"))

        preferences.resetAll()

        XCTAssertEqual(preferences.backgroundColor(for: .stores), .system)
        XCTAssertEqual(preferences.backgroundColor(for: .reminders(storeId: "store-1")), .system)
        XCTAssertEqual(preferences.backgroundColor(for: .conversation(id: "chat-1")), .system)
        XCTAssertFalse(preferences.hasBackgroundImage(for: .conversation(id: "chat-2")))
        XCTAssertEqual(preferences.dimLevel(for: .conversation(id: "chat-2")), BackgroundPreferences.defaultDimLevel)
    }

    // MARK: - Palette & Keys

    func testSelectableColors_excludesSystemAndCoversPalette() {
        XCTAssertFalse(AppBackgroundColor.selectableColors.contains(.system))
        XCTAssertEqual(AppBackgroundColor.selectableColors.count, AppBackgroundColor.allCases.count - 1)
    }

    func testStorageKeys_areUniquePerSurface() {
        let keys = [
            BackgroundSurface.stores.colorStorageKey,
            BackgroundSurface.reminders(storeId: "store-1").colorStorageKey,
            BackgroundSurface.reminders(storeId: "store-2").colorStorageKey,
            BackgroundSurface.conversation(id: "store-1").colorStorageKey,
            BackgroundSurface.conversation(id: "chat-1").colorStorageKey,
            BackgroundSurface.conversation(id: "chat-2").colorStorageKey
        ]
        XCTAssertEqual(Set(keys).count, keys.count)
    }

    /// Conversation ids come from Firestore, so the file name must never carry
    /// path separators or other characters straight through.
    func testImageFileName_sanitizesConversationIds() {
        let name = BackgroundSurface.conversation(id: "../../etc/passwd").imageFileName
        let base = String(name.dropLast(".jpg".count))

        XCTAssertTrue(name.hasSuffix(".jpg"))
        XCTAssertFalse(base.contains("/"))
        XCTAssertFalse(base.contains("."))
    }

    /// Ids that differ only in characters a naive sanitizer would fold together
    /// must still get their own file.
    func testImageFileName_doesNotCollideOnSimilarIds() {
        XCTAssertNotEqual(
            BackgroundSurface.conversation(id: "chat-1").imageFileName,
            BackgroundSurface.conversation(id: "chat_1").imageFileName
        )
    }

    func testImageFileNames_areUniquePerSurface() {
        let names = [
            BackgroundSurface.stores.imageFileName,
            BackgroundSurface.reminders(storeId: "store-1").imageFileName,
            BackgroundSurface.reminders(storeId: "store-2").imageFileName,
            BackgroundSurface.conversation(id: "store-1").imageFileName,
            BackgroundSurface.conversation(id: "chat-1").imageFileName,
            BackgroundSurface.conversation(id: "chat-2").imageFileName
        ]
        XCTAssertEqual(Set(names).count, names.count)
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
