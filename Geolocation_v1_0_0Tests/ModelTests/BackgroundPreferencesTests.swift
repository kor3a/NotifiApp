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

    /// The HSB components shading works in.
    private func components(of color: Color) -> (hue: CGFloat, saturation: CGFloat, brightness: CGFloat) {
        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
        XCTAssertTrue(UIColor(color).getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha))
        return (hue, saturation, brightness)
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

    // MARK: - Shade

    func testShadeLevel_defaultsToZeroAndClamps() {
        XCTAssertEqual(preferences.shadeLevel(for: .stores), 0)

        preferences.setShadeLevel(-4, for: .stores)
        XCTAssertEqual(preferences.shadeLevel(for: .stores), -1)

        preferences.setShadeLevel(4, for: .stores)
        XCTAssertEqual(preferences.shadeLevel(for: .stores), 1)
    }

    func testShadeLevel_persistsAcrossInstances() {
        preferences.setShadeLevel(0.65, for: .stores)

        let reloaded = BackgroundPreferences(defaults: defaults, imageDirectory: imageDirectory)
        XCTAssertEqual(reloaded.shadeLevel(for: .stores), 0.65, accuracy: 0.0001)
    }

    func testShadeLevel_isIsolatedPerSurface() {
        preferences.setShadeLevel(0.5, for: .stores)

        XCTAssertEqual(preferences.shadeLevel(for: .stores), 0.5, accuracy: 0.0001)
        XCTAssertEqual(preferences.shadeLevel(for: .reminders(storeId: "store-1")), 0)
        XCTAssertEqual(preferences.shadeLevel(for: .conversation(id: "chat-1")), 0)
    }

    /// The shade is a property of the surface, not of the color, so trying out
    /// swatches doesn't throw away the depth the user already settled on.
    func testShadeLevel_survivesAColorChange() {
        preferences.setShadeLevel(0.8, for: .stores)
        preferences.setBackgroundColor(.sand, for: .stores)

        XCTAssertEqual(preferences.shadeLevel(for: .stores), 0.8, accuracy: 0.0001)
    }

    // MARK: - Shading

    func testShaded_zeroLeavesTheColorUntouched() {
        for color in AppBackgroundColor.allCases {
            let base = color.fill(for: .light)
            XCTAssertEqual(base.shaded(by: 0), base, "\(color.displayName) changed at shade 0")
        }
    }

    /// The reason the slider exists: a light-mode palette entry has to be able
    /// to reach a genuinely dark tone, not just a slightly duller pale one.
    func testShaded_positiveDarkensEveryColorIntoDarkTerritory() {
        for color in AppBackgroundColor.allCases {
            let base = components(of: color.fill(for: .light)).brightness
            let half = components(of: color.fill(for: .light, shade: 0.5)).brightness
            let full = components(of: color.fill(for: .light, shade: 1)).brightness

            XCTAssertLessThan(half, base, "\(color.displayName) didn't darken at half shade")
            XCTAssertLessThan(full, half, "\(color.displayName) didn't keep darkening")
            XCTAssertLessThanOrEqual(
                Double(full), Color.maxShadeBrightness + 0.01,
                "\(color.displayName) never reaches a genuinely dark tone"
            )
        }
    }

    func testShaded_negativeLightensEveryColor() {
        for color in AppBackgroundColor.allCases {
            let base = components(of: color.fill(for: .dark)).brightness
            let lifted = components(of: color.fill(for: .dark, shade: -1)).brightness

            XCTAssertGreaterThan(lifted, base, "\(color.displayName) didn't lighten")
        }
    }

    /// Darkening lifts saturation so the hue survives the drop in brightness —
    /// but proportionally, so a near-neutral choice stays near-neutral instead
    /// of picking up a color cast.
    func testShaded_keepsHueWithoutTintingNeutrals() {
        let midnight = components(of: AppBackgroundColor.midnight.fill(for: .light, shade: 1))
        XCTAssertGreaterThan(midnight.saturation, 0.1, "Midnight lost its hue when darkened")

        let graphite = components(of: AppBackgroundColor.graphite.fill(for: .light, shade: 1))
        XCTAssertLessThan(graphite.saturation, 0.1, "Graphite picked up a color cast when darkened")
    }

    func testShaded_clampsOutOfRangeValues() {
        XCTAssertEqual(
            components(of: AppBackgroundColor.midnight.fill(for: .light, shade: 5)).brightness,
            components(of: AppBackgroundColor.midnight.fill(for: .light, shade: 1)).brightness,
            accuracy: 0.001
        )
        XCTAssertEqual(
            components(of: AppBackgroundColor.midnight.fill(for: .light, shade: -5)).brightness,
            components(of: AppBackgroundColor.midnight.fill(for: .light, shade: -1)).brightness,
            accuracy: 0.001
        )
    }

    // MARK: - Applying One Look Everywhere

    func testApplyBackground_copiesColorAndShadeToEveryTarget() {
        let source = BackgroundSurface.reminders(storeId: "store-1")
        preferences.setBackgroundColor(.ocean, for: source)
        preferences.setShadeLevel(0.4, for: source)
        preferences.setBackgroundColor(.rose, for: .reminders(storeId: "store-2"))

        XCTAssertTrue(preferences.applyBackground(from: source, to: [
            .reminders(storeId: "store-1"),
            .reminders(storeId: "store-2"),
            .reminders(storeId: "store-3")
        ]))

        for id in ["store-1", "store-2", "store-3"] {
            XCTAssertEqual(preferences.backgroundColor(for: .reminders(storeId: id)), .ocean)
            XCTAssertEqual(preferences.shadeLevel(for: .reminders(storeId: id)), 0.4, accuracy: 0.0001)
        }
    }

    /// The Stores screen can push its own look out to the reminder lists, and
    /// must not disturb anything else.
    func testApplyBackground_leavesUnlistedSurfacesAlone() {
        preferences.setBackgroundColor(.sand, for: .stores)
        preferences.setBackgroundColor(.plum, for: .conversation(id: "chat-1"))

        preferences.applyBackground(from: .stores, to: [.reminders(storeId: "store-1")])

        XCTAssertEqual(preferences.backgroundColor(for: .reminders(storeId: "store-1")), .sand)
        XCTAssertEqual(preferences.backgroundColor(for: .conversation(id: "chat-1")), .plum)
    }

    /// Callers pass every store id, including the one being edited — the source
    /// is skipped rather than rewritten.
    func testApplyBackground_skipsTheSourceSurface() throws {
        let source = BackgroundSurface.reminders(storeId: "store-1")
        let data = try sampleImageData(width: 300, height: 300)
        preferences.setBackgroundImage(from: data, for: source)
        preferences.setDimLevel(0.5, for: source)

        preferences.applyBackground(from: source, to: [source, .reminders(storeId: "store-2")])

        XCTAssertTrue(preferences.hasBackgroundImage(for: source))
        XCTAssertEqual(preferences.dimLevel(for: source), 0.5, accuracy: 0.0001)
    }

    func testApplyBackground_copiesPhotoAndFade() throws {
        let source = BackgroundSurface.reminders(storeId: "store-1")
        let data = try sampleImageData(width: 300, height: 300)
        preferences.setBackgroundImage(from: data, for: source)
        preferences.setDimLevel(0.55, for: source)

        preferences.applyBackground(from: source, to: [.reminders(storeId: "store-2")])

        let target = BackgroundSurface.reminders(storeId: "store-2")
        XCTAssertTrue(preferences.hasBackgroundImage(for: target))
        XCTAssertEqual(preferences.dimLevel(for: target), 0.55, accuracy: 0.0001)

        // Written to disk, not just cached — the copy has to survive a relaunch.
        let reloaded = BackgroundPreferences(defaults: defaults, imageDirectory: imageDirectory)
        XCTAssertNotNil(reloaded.backgroundImage(for: target))
    }

    /// Without a subscription the source's photo has already fallen back to its
    /// color on screen, so the photo stays put and the color is what travels.
    func testApplyBackground_withoutPhoto_leavesTheSourcePhotoAndCopiesTheColor() throws {
        let source = BackgroundSurface.reminders(storeId: "store-1")
        let data = try sampleImageData(width: 300, height: 300)
        preferences.setBackgroundImage(from: data, for: source)

        let target = BackgroundSurface.reminders(storeId: "store-2")
        preferences.setBackgroundColor(.rose, for: target)

        preferences.applyBackground(from: source, to: [target], includingPhoto: false)

        XCTAssertTrue(preferences.hasBackgroundImage(for: source))
        XCTAssertFalse(preferences.hasBackgroundImage(for: target))
        XCTAssertEqual(preferences.backgroundColor(for: target), .system)
    }

    /// A color replaces a photo the same way picking one by hand does.
    func testApplyBackground_colorClearsATargetsPhoto() throws {
        let data = try sampleImageData(width: 300, height: 300)
        let target = BackgroundSurface.reminders(storeId: "store-2")
        preferences.setBackgroundImage(from: data, for: target)
        preferences.setBackgroundColor(.forest, for: .reminders(storeId: "store-1"))

        preferences.applyBackground(from: .reminders(storeId: "store-1"), to: [target])

        XCTAssertFalse(preferences.hasBackgroundImage(for: target))
        XCTAssertEqual(preferences.backgroundColor(for: target), .forest)
        XCTAssertEqual(preferences.dimLevel(for: target), BackgroundPreferences.defaultDimLevel)
    }

    /// Sweeping a default-looking screen resets the others rather than leaving
    /// their old look in place.
    func testApplyBackground_fromDefaultSurface_clearsTargets() {
        let target = BackgroundSurface.reminders(storeId: "store-2")
        preferences.setBackgroundColor(.rose, for: target)
        preferences.setShadeLevel(0.7, for: target)

        preferences.applyBackground(from: .reminders(storeId: "store-1"), to: [target])

        XCTAssertEqual(preferences.backgroundColor(for: target), .system)
        XCTAssertEqual(preferences.shadeLevel(for: target), 0)
    }

    func testApplyBackground_persistsAcrossInstances() {
        preferences.setBackgroundColor(.lavender, for: .stores)
        preferences.setShadeLevel(-0.3, for: .stores)

        preferences.applyBackground(from: .stores, to: [.reminders(storeId: "store-1")])

        let reloaded = BackgroundPreferences(defaults: defaults, imageDirectory: imageDirectory)
        XCTAssertEqual(reloaded.backgroundColor(for: .reminders(storeId: "store-1")), .lavender)
        XCTAssertEqual(reloaded.shadeLevel(for: .reminders(storeId: "store-1")), -0.3, accuracy: 0.0001)
    }

    // MARK: - Reset

    func testReset_clearsOnlyTheGivenSurface() throws {
        let data = try sampleImageData(width: 300, height: 300)
        preferences.setBackgroundImage(from: data, for: .stores)
        preferences.setShadeLevel(0.4, for: .stores)
        preferences.setBackgroundColor(.sand, for: .reminders(storeId: "store-1"))
        preferences.setShadeLevel(0.6, for: .reminders(storeId: "store-1"))

        preferences.reset(.stores)

        XCTAssertFalse(preferences.hasBackgroundImage(for: .stores))
        XCTAssertEqual(preferences.shadeLevel(for: .stores), 0)
        XCTAssertEqual(preferences.backgroundColor(for: .reminders(storeId: "store-1")), .sand)
        XCTAssertEqual(preferences.shadeLevel(for: .reminders(storeId: "store-1")), 0.6, accuracy: 0.0001)
    }

    func testResetAll_clearsEverySurfaceIncludingConversationsAndPhotos() throws {
        let data = try sampleImageData(width: 300, height: 300)
        preferences.setBackgroundColor(.ocean, for: .stores)
        preferences.setBackgroundColor(.sand, for: .reminders(storeId: "store-1"))
        preferences.setBackgroundColor(.plum, for: .conversation(id: "chat-1"))
        preferences.setBackgroundImage(from: data, for: .conversation(id: "chat-2"))
        preferences.setDimLevel(0.7, for: .conversation(id: "chat-2"))
        preferences.setShadeLevel(0.9, for: .stores)

        preferences.resetAll()

        XCTAssertEqual(preferences.shadeLevel(for: .stores), 0)
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
        let surfaces: [BackgroundSurface] = [
            .stores,
            .reminders(storeId: "store-1"),
            .reminders(storeId: "store-2"),
            .conversation(id: "store-1"),
            .conversation(id: "chat-1"),
            .conversation(id: "chat-2")
        ]
        // Every key of every kind, so a shade key can never land on another
        // surface's color or dim key either.
        let keys = surfaces.flatMap { [$0.colorStorageKey, $0.dimStorageKey, $0.shadeStorageKey] }
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
