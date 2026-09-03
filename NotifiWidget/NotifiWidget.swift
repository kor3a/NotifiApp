//
//  NotifiWidget.swift
//  NotifiWidget
//
//  Shows stores and their reminder counts on the home screen.
//  Reads data written by WidgetDataStore in the main app via the
//  shared App Group "group.com.kor3a.nearbuy" — the store list from
//  the group's UserDefaults, the store logos from a directory beside it.
//  Refreshes every 15 minutes; also refreshes immediately when the
//  main app calls WidgetCenter.shared.reloadAllTimelines() on open.
//

import WidgetKit
import SwiftUI
import UIKit

// MARK: - Shared Data Model
// Must match the WidgetStoreData struct in WidgetDataStore.swift (main app).

struct WidgetStoreData: Codable {
    let storeName: String
    let reminderCount: Int
    let imageURL: String?
    /// The store's logo inside the shared logo directory. Optional, and often
    /// nil early on: the app only names a file once it has that logo cached,
    /// so a row falls back to its initial disc until then.
    let logoFileName: String?
}

// MARK: - Shared Container

/// The App Group the main app publishes into. The widget only reads.
enum SharedContainer {
    static let appGroup = "group.com.kor3a.nearbuy"
    static let storesKey = "widgetStoreData"
    static let logoDirectoryName = "StoreLogos"

    static var defaults: UserDefaults? { UserDefaults(suiteName: appGroup) }

    /// A logo as the app last exported it — already downscaled for the widget,
    /// so this is a small read rather than a full-size decode under the
    /// extension's memory budget.
    static func logo(named fileName: String) -> UIImage? {
        // The name comes from our own payload, but it addresses a container the
        // app writes too, so it never gets to climb out of the directory.
        guard
            !fileName.isEmpty,
            !fileName.contains("/"),
            !fileName.contains(".."),
            let container = FileManager.default
                .containerURL(forSecurityApplicationGroupIdentifier: appGroup)
        else { return nil }

        let url = container
            .appendingPathComponent(logoDirectoryName, isDirectory: true)
            .appendingPathComponent(fileName)

        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }
}

// MARK: - Timeline Entry

struct StoreWidgetEntry: TimelineEntry {
    let date: Date
    let stores: [WidgetStoreData]
}

// MARK: - Timeline Provider

struct StoreWidgetProvider: TimelineProvider {

    func placeholder(in context: Context) -> StoreWidgetEntry {
        StoreWidgetEntry(
            date: Date(),
            stores: [
                WidgetStoreData(storeName: "Walmart", reminderCount: 3, imageURL: nil, logoFileName: nil),
                WidgetStoreData(storeName: "Target", reminderCount: 1, imageURL: nil, logoFileName: nil),
                WidgetStoreData(storeName: "Costco", reminderCount: 5, imageURL: nil, logoFileName: nil)
            ]
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (StoreWidgetEntry) -> Void) {
        completion(StoreWidgetEntry(date: Date(), stores: loadStores()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StoreWidgetEntry>) -> Void) {
        let stores = loadStores()
        let entry = StoreWidgetEntry(date: Date(), stores: stores)

        // Schedule next refresh 15 minutes from now.
        // The main app also triggers an immediate refresh by calling
        // WidgetCenter.shared.reloadAllTimelines() whenever stores or
        // reminder counts change, so the widget stays up-to-date on open.
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextRefresh))
        completion(timeline)
    }

    // MARK: - Private helpers

    private func loadStores() -> [WidgetStoreData] {
        guard
            let defaults = SharedContainer.defaults,
            let data = defaults.data(forKey: SharedContainer.storesKey),
            let stores = try? JSONDecoder().decode([WidgetStoreData].self, from: data)
        else {
            return []
        }
        return stores.sorted { $0.reminderCount > $1.reminderCount }
    }
}

// MARK: - Widget Configuration

struct NotifiWidget: Widget {
    let kind: String = "NotifiWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StoreWidgetProvider()) { entry in
            // The canvas is the entry view's own containerBackground, so
            // it can read the color scheme; and the system's content margins
            // are off so the widget's padding is the padding you see rather
            // than a second inset on top of Apple's.
            NotifiWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("My Stores")
        .description("See your stores and reminder counts at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

// MARK: - Previews

#Preview("Small", as: .systemSmall) {
    NotifiWidget()
} timeline: {
    StoreWidgetEntry(date: .now, stores: [
        WidgetStoreData(storeName: "Walmart", reminderCount: 3, imageURL: nil, logoFileName: nil),
        WidgetStoreData(storeName: "Target", reminderCount: 0, imageURL: nil, logoFileName: nil),
        WidgetStoreData(storeName: "Costco", reminderCount: 5, imageURL: nil, logoFileName: nil)
    ])
}

#Preview("Medium", as: .systemMedium) {
    NotifiWidget()
} timeline: {
    StoreWidgetEntry(date: .now, stores: [
        WidgetStoreData(storeName: "Walmart", reminderCount: 3, imageURL: nil, logoFileName: nil),
        WidgetStoreData(storeName: "Target", reminderCount: 1, imageURL: nil, logoFileName: nil),
        WidgetStoreData(storeName: "Costco", reminderCount: 5, imageURL: nil, logoFileName: nil),
        WidgetStoreData(storeName: "Whole Foods", reminderCount: 2, imageURL: nil, logoFileName: nil)
    ])
}

#Preview("Large", as: .systemLarge) {
    NotifiWidget()
} timeline: {
    StoreWidgetEntry(date: .now, stores: [
        WidgetStoreData(storeName: "Walmart", reminderCount: 3, imageURL: nil, logoFileName: nil),
        WidgetStoreData(storeName: "Target", reminderCount: 1, imageURL: nil, logoFileName: nil),
        WidgetStoreData(storeName: "Costco", reminderCount: 5, imageURL: nil, logoFileName: nil),
        WidgetStoreData(storeName: "Whole Foods", reminderCount: 2, imageURL: nil, logoFileName: nil),
        WidgetStoreData(storeName: "Trader Joe's", reminderCount: 0, imageURL: nil, logoFileName: nil)
    ])
}

#Preview("Empty", as: .systemMedium) {
    NotifiWidget()
} timeline: {
    StoreWidgetEntry(date: .now, stores: [])
}
