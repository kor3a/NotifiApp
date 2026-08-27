//
//  WidgetDataStore.swift
//  Geolocation_v1.0.0
//
//  Writes the user's store list and reminder counts into the shared App Group
//  ("group.com.kor3a.nearbuy") so the NotifiWidget extension can read them
//  without Firebase access.
//
//  Call `WidgetDataStore.shared.updateWidgetData(from:)` whenever the list of
//  stores or their reminder counts changes.  The method encodes the data and
//  calls `WidgetCenter.shared.reloadAllTimelines()` so the widget refreshes
//  immediately, in addition to its scheduled 15-minute refresh.
//
//  Store logos travel the same way but as files rather than defaults: the
//  widget can't reach StoreLogoProvider's cache (it lives in the app's Caches
//  directory) and can't resolve a logo URL for itself (that needs Firestore),
//  so the app exports widget-sized copies into the group container and the
//  payload names the file each row should look for.
//

import Foundation
import UIKit
import WidgetKit

// MARK: - Shared Data Model
// WidgetStoreData must stay in sync with the struct in NotifiWidget.swift.

struct WidgetStoreData: Codable {
    let storeName: String
    let reminderCount: Int
    let imageURL: String?
    /// The store's logo inside the shared logo directory, when the app had one
    /// cached at write time. Nil leaves the widget to draw its initial disc.
    let logoFileName: String?
}

// MARK: - Store

final class WidgetDataStore {

    static let shared = WidgetDataStore()

    private let appGroupSuite = "group.com.kor3a.nearbuy"
    static let storesKey = "widgetStoreData"
    /// Directory inside the App Group container holding the exported logos.
    static let logoDirectoryName = "StoreLogos"

    /// Longest edge of an exported logo, in pixels. The widget draws them at
    /// 24pt or less, so 120 covers a 3x screen with room to spare — and the
    /// extension renders under a tight memory budget that a full-size logo
    /// would eat several times over.
    private static let logoMaxPixels: CGFloat = 120

    /// Exports run off the main thread: each logo is read, downscaled and
    /// re-encoded, and the caller is usually a view model mid-update.
    private static let exportQueue = DispatchQueue(
        label: "WidgetDataStore.logoExport",
        qos: .utility
    )

    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupSuite)
    }

    private var sharedLogoDirectory: URL? {
        guard let container = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupSuite)
        else { return nil }

        let directory = container.appendingPathComponent(
            Self.logoDirectoryName,
            isDirectory: true
        )
        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        return directory
    }

    private init() {}

    // MARK: - Write

    /// Encodes `userStoreItems` and pushes it to the widget.
    /// Triggers an immediate widget refresh in addition to the 15-minute schedule.
    func updateWidgetData(from userStoreItems: [UserStoreItem]) {
        write(
            userStoreItems
                .sorted { $0.store.reminderCount > $1.store.reminderCount }
                .map { ($0.store.name, $0.store.reminderCount, $0.store.imageURL) }
        )
    }

    /// Re-exports the logos for the stores already on the widget.
    ///
    /// Called when a logo finishes downloading, so a store that was showing its
    /// initial disc picks the logo up instead of waiting for the next store or
    /// reminder change — which, after a first launch, might be a long way off.
    func refreshLogos() {
        let existing = loadWidgetData()
        guard !existing.isEmpty else { return }
        write(existing.map { ($0.storeName, $0.reminderCount, $0.imageURL) })
    }

    /// The shared path: name each store's logo, publish the payload, then copy
    /// the logos themselves across in the background.
    private func write(_ stores: [(name: String, reminderCount: Int, imageURL: String?)]) {
        // Resolving a logo's file goes through StoreLogoProvider, whose resolution
        // cache is main-thread-only — as it already is when a row asks it for an
        // image. Every caller here is mid-update on @Published state, so it holds;
        // only the copying below moves off the main thread.
        let sources: [String: URL] = stores.reduce(into: [:]) { result, store in
            if let file = StoreLogoProvider.shared.cachedLogoFile(for: store.name) {
                result[store.name] = file
            }
        }

        let payload = stores.map {
            WidgetStoreData(
                storeName: $0.name,
                reminderCount: $0.reminderCount,
                imageURL: $0.imageURL,
                logoFileName: sources[$0.name]?.lastPathComponent
            )
        }

        guard let encoded = try? JSONEncoder().encode(payload) else { return }
        sharedDefaults?.set(encoded, forKey: Self.storesKey)

        // Counts shouldn't wait on image work, so the widget is told now and
        // again below if the export actually changed a logo.
        WidgetCenter.shared.reloadAllTimelines()

        // Keyed by file name, not store name: the logo cache deliberately points
        // prefixed names at one file ("Walmart Supercenter" reuses walmart.jpg),
        // so the same URL can arrive twice and the duplicate is dropped rather
        // than trapped on.
        exportLogos(Dictionary(
            sources.values.map { ($0.lastPathComponent, $0) },
            uniquingKeysWith: { first, _ in first }
        ))
    }

    // MARK: - Logo Export

    /// Copies each logo into the App Group at widget size, and clears out the
    /// ones no store claims any more.
    private func exportLogos(_ sources: [String: URL]) {
        Self.exportQueue.async { [weak self] in
            guard let self = self, let directory = self.sharedLogoDirectory else { return }
            let fileManager = FileManager.default
            var exportedSomething = false

            for (fileName, source) in sources {
                let destination = directory.appendingPathComponent(fileName)
                guard !self.isUpToDate(destination, comparedTo: source) else { continue }
                guard let data = self.widgetSizedPNG(at: source) else { continue }

                try? data.write(to: destination)
                exportedSomething = true
            }

            // Stores come and go; their logos shouldn't outlive them in here.
            if let existing = try? fileManager.contentsOfDirectory(atPath: directory.path) {
                for fileName in existing where sources[fileName] == nil {
                    try? fileManager.removeItem(at: directory.appendingPathComponent(fileName))
                }
            }

            // A prune alone changes nothing on screen — those stores are gone
            // from the payload too — so only a new logo is worth a reload.
            if exportedSomething {
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
    }

    /// True when the exported copy is at least as new as the logo it came from,
    /// so an unchanged logo isn't decoded and re-encoded on every update.
    private func isUpToDate(_ destination: URL, comparedTo source: URL) -> Bool {
        let fileManager = FileManager.default
        guard
            let destinationDate = (try? fileManager.attributesOfItem(atPath: destination.path))?[.modificationDate] as? Date,
            let sourceDate = (try? fileManager.attributesOfItem(atPath: source.path))?[.modificationDate] as? Date
        else { return false }

        return destinationDate >= sourceDate
    }

    /// A small copy of a logo, no longer than `logoMaxPixels` on its long edge.
    ///
    /// PNG rather than JPEG: the cache stores whatever bytes came down the wire
    /// under a `.jpg` name, so a logo with a transparent background would pick
    /// up a black square on the way through a JPEG encoder.
    private func widgetSizedPNG(at source: URL) -> Data? {
        guard
            let data = try? Data(contentsOf: source),
            let image = UIImage(data: data)
        else { return nil }

        let longestEdge = max(image.size.width, image.size.height)
        guard longestEdge > 0 else { return nil }
        guard longestEdge > Self.logoMaxPixels else { return image.pngData() }

        let ratio = Self.logoMaxPixels / longestEdge
        let target = CGSize(
            width: image.size.width * ratio,
            height: image.size.height * ratio
        )

        let format = UIGraphicsImageRendererFormat.default()
        // Points are pixels here — left at the screen's scale the renderer would
        // hand back a 3x image and undo the downscale.
        format.scale = 1
        format.opaque = false

        return UIGraphicsImageRenderer(size: target, format: format)
            .image { _ in image.draw(in: CGRect(origin: .zero, size: target)) }
            .pngData()
    }

    // MARK: - Read (convenience, for testing / previews from main app)

    func loadWidgetData() -> [WidgetStoreData] {
        guard
            let data = sharedDefaults?.data(forKey: Self.storesKey),
            let stores = try? JSONDecoder().decode([WidgetStoreData].self, from: data)
        else { return [] }
        return stores
    }
}
