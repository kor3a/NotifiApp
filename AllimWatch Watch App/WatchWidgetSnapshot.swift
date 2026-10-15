//
//  WatchWidgetSnapshot.swift
//  AllimWatch Watch App
//
//  What the watch app hands to its widget, and the deep link the widget hands
//  back.
//
//  The widget runs in its own process and can't see WatchDataStore, so the app
//  writes a small snapshot of the store list into the shared App Group and the
//  widget reads it from there. This file is compiled into both targets — it is
//  a member of "AllimWatch Widget" through a target-membership exception on
//  this folder — so the two sides can't disagree about the format.
//

import Foundation

struct WatchWidgetSnapshot: Codable, Equatable {

    struct Store: Codable, Equatable, Identifiable {
        let id: String
        let name: String
        let reminderCount: Int
    }

    /// Every store, in the user's order. The widget picks out the ones with
    /// something left to get.
    let stores: [Store]
    let isSignedIn: Bool

    /// Stores that still have items outstanding, in the user's order.
    var storesWithItems: [Store] {
        stores.filter { $0.reminderCount > 0 }
    }

    var totalItems: Int {
        stores.reduce(0) { $0 + $1.reminderCount }
    }

    // MARK: - Shared Storage

    /// The App Group the iPhone app and its widget already use. On the watch it
    /// is a separate container from the phone's, shared only by the watch app
    /// and the watch widget.
    static let appGroupId = "group.com.kor3a.nearbuy"

    /// The widget kind, used both to declare the widget and to reload it.
    static let widgetKind = "AllimWatchStoresWidget"

    private static let defaultsKey = "watch.widgetSnapshot"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupId)
    }

    static func load() -> WatchWidgetSnapshot? {
        guard let data = defaults?.data(forKey: defaultsKey) else { return nil }
        return try? JSONDecoder().decode(WatchWidgetSnapshot.self, from: data)
    }

    /// Writes the snapshot. Returns false when nothing changed, so the caller
    /// can skip a widget reload — watchOS budgets those.
    @discardableResult
    func save() -> Bool {
        guard Self.load() != self,
              let data = try? JSONEncoder().encode(self) else { return false }
        Self.defaults?.set(data, forKey: Self.defaultsKey)
        return true
    }

    // MARK: - Deep Link

    /// The link every widget tap opens: the store list, whatever screen the
    /// app was last left on. Without it, watchOS would resume the app where it
    /// was, which is often some store's reminders rather than the overview the
    /// widget is a summary of.
    static let storeListURL = URL(string: "allimwatch://stores")!

    static func isStoreListURL(_ url: URL) -> Bool {
        url.scheme == storeListURL.scheme && url.host == storeListURL.host
    }
}
