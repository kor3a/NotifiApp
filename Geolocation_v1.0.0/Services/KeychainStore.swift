//
//  KeychainStore.swift
//  Geolocation_v1.0.0
//
//  Created on 8/25/26.
//

import Foundation
import Security

/// A small wrapper over the iOS keychain for data that has to outlive the app
/// container.
///
/// Everything else the app writes — `UserDefaults`, Application Support, the
/// app group container — lives inside the app's container, and iOS deletes that
/// container when the user deletes the app. Keychain items are stored outside
/// it and survive a delete and reinstall of the same bundle identifier, so
/// anything the user would be upset to re-enter (membership card numbers) is
/// mirrored here.
///
/// Items are written with `kSecAttrAccessibleAfterFirstUnlock` so the app can
/// still read them when it is launched into the background by a geofence event,
/// and so they travel in an encrypted device backup. They are *not* marked
/// `kSecAttrSynchronizable`: this is device-local storage that happens to
/// survive reinstalls, not an iCloud sync.
struct KeychainStore {
    enum KeychainError: LocalizedError {
        /// A keychain call failed with something other than "not found".
        case unhandled(OSStatus)

        var errorDescription: String? {
            switch self {
            case .unhandled(let status):
                if let message = SecCopyErrorMessageString(status, nil) {
                    return message as String
                }
                return "OSStatus \(status)"
            }
        }
    }

    /// Namespace for this store's items, so unrelated features can share the
    /// keychain without colliding on account names.
    let service: String

    // MARK: - Read

    /// The data stored under `account`, or `nil` if there is none.
    ///
    /// Throws for real failures (a locked device, a missing entitlement) so
    /// callers can tell "the user has no backup" apart from "the backup could
    /// not be read right now" — the difference matters, because overwriting a
    /// backup we failed to read would destroy it.
    func data(account: String) throws -> Data? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess:
            return result as? Data
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError.unhandled(status)
        }
    }

    /// Every account name in this service, used to find orphaned items.
    func accounts() throws -> [String] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess:
            let items = result as? [[String: Any]] ?? []
            return items.compactMap { $0[kSecAttrAccount as String] as? String }
        case errSecItemNotFound:
            return []
        default:
            throw KeychainError.unhandled(status)
        }
    }

    // MARK: - Write

    /// Store `data` under `account`, replacing anything already there.
    func set(_ data: Data, account: String) throws {
        let query = baseQuery(account: account)
        let attributes: [String: Any] = [kSecValueData as String: data]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        switch status {
        case errSecSuccess:
            return
        case errSecItemNotFound:
            var newItem = query
            newItem[kSecValueData as String] = data
            newItem[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            let addStatus = SecItemAdd(newItem as CFDictionary, nil)
            guard addStatus == errSecSuccess else { throw KeychainError.unhandled(addStatus) }
        default:
            throw KeychainError.unhandled(status)
        }
    }

    /// Remove the item under `account`. Removing something that isn't there
    /// succeeds — the caller wanted it gone either way.
    func removeItem(account: String) throws {
        let status = SecItemDelete(baseQuery(account: account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unhandled(status)
        }
    }

    // MARK: - Helpers

    private func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}
