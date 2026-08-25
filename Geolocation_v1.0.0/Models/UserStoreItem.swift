//
//  UserStoreItem.swift
//  Geolocation_v1.0.0
//
//  Created by Claude on 11/6/24.
//

import Foundation

/// Represents a store that a user has added to their list
/// Combines store information with the user_store document ID
struct UserStoreItem: Identifiable, Hashable {
    let id: String // user_store document ID
    let store: Store
    let permission: StorePermission // User's permission level for this store
    let sharedStoreGroupId: String? // If shared with Can Edit, this links to the shared group
    let sourceUserStoreId: String? // If View Only, points to owner's user_store ID
    var sharedFromName: String? // Display name of user who shared this store (for recipient)
    let sharedFromId: String? // User ID of who shared this store (for looking up current name)
    var sharedWith: [String]? // Names of users this store is shared with (for owner)
    let notificationsEnabled: Bool // Whether notifications are enabled for this store
    /// True when this store was originally the user's OWN store and later merged into
    /// someone else's shared list (see `MessagingService.mergeStoreReminders`). The user
    /// is a normal `.edit` participant from here on, but leaving the share must hand the
    /// store back to them instead of deleting it — they owned it before the merge.
    var mergedFromOwnStore: Bool = false

    /// Whether this store is being shared with other users or was shared to the current user
    var isShared: Bool {
        if let sharedWith = sharedWith, !sharedWith.isEmpty {
            return true
        }
        return sharedFromName != nil
    }

    /// Returns the ID to use for fetching reminders.
    /// - Owners always use their own user_store ID, even if sourceUserStoreId is set
    ///   (the merge flow sets sourceUserStoreId for tracking purposes without changing
    ///   which reminders the owner sees).
    /// - View-only and edit recipients use sourceUserStoreId (owner's store) or sharedStoreGroupId.
    var reminderStoreId: String {
        guard permission != .owner else { return id }
        return sourceUserStoreId ?? sharedStoreGroupId ?? id
    }
}
