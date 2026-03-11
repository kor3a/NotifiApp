//
//  NotifiWidget.swift
//  NotifiWidget
//
//  Shows stores and their reminder counts on the home screen.
//  Reads data written by WidgetDataStore in the main app via the
//  shared App Group "group.com.kor3a.nearbuy".
//  Refreshes every 15 minutes; also refreshes immediately when the
//  main app calls WidgetCenter.shared.reloadAllTimelines() on open.
//

import WidgetKit
import SwiftUI

// MARK: - Shared Data Model
// Must match the WidgetStoreData struct in WidgetDataStore.swift (main app).

struct WidgetStoreData: Codable {
    let storeName: String
    let reminderCount: Int
    let imageURL: String?
}

// MARK: - Timeline Entry

struct StoreWidgetEntry: TimelineEntry {
    let date: Date
    let stores: [WidgetStoreData]
}

// MARK: - Timeline Provider

struct StoreWidgetProvider: TimelineProvider {

    private let suiteName = "group.com.kor3a.nearbuy"
    private let storesKey = "widgetStoreData"

    func placeholder(in context: Context) -> StoreWidgetEntry {
        StoreWidgetEntry(
            date: Date(),
            stores: [
                WidgetStoreData(storeName: "Walmart", reminderCount: 3, imageURL: nil),
                WidgetStoreData(storeName: "Target", reminderCount: 1, imageURL: nil),
                WidgetStoreData(storeName: "Costco", reminderCount: 5, imageURL: nil)
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
            let defaults = UserDefaults(suiteName: suiteName),
            let data = defaults.data(forKey: storesKey),
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
            NotifiWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("My Stores")
        .description("See your stores and reminder counts at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Previews

#Preview("Small", as: .systemSmall) {
    NotifiWidget()
} timeline: {
    StoreWidgetEntry(date: .now, stores: [
        WidgetStoreData(storeName: "Walmart", reminderCount: 3, imageURL: nil),
        WidgetStoreData(storeName: "Target", reminderCount: 0, imageURL: nil),
        WidgetStoreData(storeName: "Costco", reminderCount: 5, imageURL: nil)
    ])
}

#Preview("Medium", as: .systemMedium) {
    NotifiWidget()
} timeline: {
    StoreWidgetEntry(date: .now, stores: [
        WidgetStoreData(storeName: "Walmart", reminderCount: 3, imageURL: nil),
        WidgetStoreData(storeName: "Target", reminderCount: 1, imageURL: nil),
        WidgetStoreData(storeName: "Costco", reminderCount: 5, imageURL: nil),
        WidgetStoreData(storeName: "Whole Foods", reminderCount: 2, imageURL: nil)
    ])
}

#Preview("Large", as: .systemLarge) {
    NotifiWidget()
} timeline: {
    StoreWidgetEntry(date: .now, stores: [
        WidgetStoreData(storeName: "Walmart", reminderCount: 3, imageURL: nil),
        WidgetStoreData(storeName: "Target", reminderCount: 1, imageURL: nil),
        WidgetStoreData(storeName: "Costco", reminderCount: 5, imageURL: nil),
        WidgetStoreData(storeName: "Whole Foods", reminderCount: 2, imageURL: nil),
        WidgetStoreData(storeName: "Trader Joe's", reminderCount: 0, imageURL: nil)
    ])
}
