//
//  WatchSyncModels.swift
//  Geolocation_v1.0.0
//
//  The wire format spoken between the iPhone app and the Apple Watch app.
//
//  IMPORTANT — these declarations are mirrored verbatim in
//  "AllimWatch Watch App/WatchSyncModels.swift". The watch target cannot see the
//  iOS target's sources, so the two copies must be edited together, the same way
//  WidgetStoreData is mirrored into the widget extension. Changing a property
//  name here without changing it there silently breaks decoding on the watch.
//

import Foundation

// MARK: - Payloads

/// A store as the watch shows it: a name, a logo, and how many items are still
/// outstanding. `id` is the user_store document ID, which the watch sends back
/// when asking for that store's reminders.
struct WatchStorePayload: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let reminderCount: Int
    let imageURL: String?
    /// False for stores shared with View Only permission — the watch renders
    /// those read-only rather than offering a checkbox that would be rejected.
    let canEdit: Bool
}

/// A single reminder, trimmed to what a watch screen can actually show.
struct WatchReminderPayload: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let isDone: Bool
    let quantity: Int?
    let isOutOfStock: Bool
    let category: String?
    let sortOrder: Int?
    let createdAt: TimeInterval
}

/// The store list plus the sign-in state it was captured under. The watch has no
/// Firebase session of its own, so `isSignedIn == false` is how it learns to ask
/// the user to sign in on their phone instead of showing an empty list.
struct WatchStoreListPayload: Codable {
    let stores: [WatchStorePayload]
    let isSignedIn: Bool
    let updatedAt: TimeInterval
}

/// One store's reminders, tagged with the store they belong to so a reply that
/// arrives after the user has already navigated elsewhere can be discarded.
struct WatchReminderListPayload: Codable {
    let storeId: String
    let reminders: [WatchReminderPayload]
    let updatedAt: TimeInterval
}

// MARK: - Message Keys

/// Keys and action names used in the WCSession dictionaries. String literals on
/// both sides of a wire are exactly the kind of thing that drifts, so both the
/// phone and the watch read them from here.
enum WatchSyncKey {
    /// Names the kind of request in a message dictionary.
    static let action = "action"

    /// Watch → phone: send the current store list.
    static let actionRequestStores = "requestStores"
    /// Watch → phone: send one store's reminders (`storeId` carries which).
    static let actionRequestReminders = "requestReminders"
    /// Watch → phone: check an item on or off (`reminderId`, `isDone`).
    static let actionToggleReminder = "toggleReminder"

    static let storeId = "storeId"
    static let reminderId = "reminderId"
    static let isDone = "isDone"

    /// JSON-encoded `WatchStoreListPayload`.
    static let storeList = "storeList"
    /// JSON-encoded `WatchReminderListPayload`.
    static let reminderList = "reminderList"
    /// Set on a reply when the request could not be served.
    static let error = "error"
}
