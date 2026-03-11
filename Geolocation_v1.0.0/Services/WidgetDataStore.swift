//
//  WidgetDataStore.swift
//  Geolocation_v1.0.0
//
//  Writes the user's store list and reminder counts into the shared App Group
//  UserDefaults ("group.com.kor3a.nearbuy") so the NotifiWidget extension can
//  read them without Firebase access.
//
//  Call `WidgetDataStore.shared.updateWidgetData(from:)` whenever the list of
//  stores or their reminder counts changes.  The method encodes the data and
//  calls `WidgetCenter.shared.reloadAllTimelines()` so the widget refreshes
//  immediately, in addition to its scheduled 15-minute refresh.
//

import Foundation
import WidgetKit

// MARK: - Shared Data Model
// WidgetStoreData must stay in sync with the struct in NotifiWidget.swift.

struct WidgetStoreData: Codable {
    let storeName: String
    let reminderCount: Int
    let imageURL: String?
}

// MARK: - Store

final class WidgetDataStore {

    static let shared = WidgetDataStore()

    private let appGroupSuite = "group.com.kor3a.nearbuy"
    static let storesKey = "widgetStoreData"

    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupSuite)
    }

    private init() {}

    // MARK: - Write

    /// Encodes `userStoreItems` and pushes it to the widget.
    /// Triggers an immediate widget refresh in addition to the 15-minute schedule.
    func updateWidgetData(from userStoreItems: [UserStoreItem]) {
        let payload = userStoreItems
            .sorted { $0.store.reminderCount > $1.store.reminderCount }
            .map {
                WidgetStoreData(
                    storeName: $0.store.name,
                    reminderCount: $0.store.reminderCount,
                    imageURL: $0.store.imageURL
                )
            }

        guard let encoded = try? JSONEncoder().encode(payload) else { return }
        sharedDefaults?.set(encoded, forKey: Self.storesKey)

        WidgetCenter.shared.reloadAllTimelines()
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
