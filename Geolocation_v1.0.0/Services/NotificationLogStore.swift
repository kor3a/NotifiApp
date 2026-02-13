//
//  NotificationLogStore.swift
//  Geolocation_v1.0.0
//
//  Created by Claude Code
//

import Foundation
import Combine

class NotificationLogStore: ObservableObject {
    static let shared = NotificationLogStore()

    @Published private(set) var entries: [NotificationLogEntry] = []

    private let userDefaultsKey = "notificationLogEntries"
    private let maxEntries = 100 // Limit to prevent excessive storage

    private init() {
        loadEntries()
    }

    // MARK: - Public Methods

    func addEntry(storeName: String, reminderCount: Int) {
        let entry = NotificationLogEntry(storeName: storeName, reminderCount: reminderCount)

        // Insert at the beginning (most recent first)
        entries.insert(entry, at: 0)

        // Limit the number of entries
        if entries.count > maxEntries {
            entries = Array(entries.prefix(maxEntries))
        }

        saveEntries()
        #if DEBUG
        print("📝 NotificationLogStore: Added entry for \(storeName) with \(reminderCount) reminder(s)")
        #endif
    }

    func clearAll() {
        entries.removeAll()
        saveEntries()
        #if DEBUG
        print("🗑️ NotificationLogStore: Cleared all entries")
        #endif
    }

    // MARK: - Private Methods

    private func loadEntries() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else {
            #if DEBUG
            print("📖 NotificationLogStore: No saved entries found")
            #endif
            return
        }

        do {
            let decoder = JSONDecoder()
            entries = try decoder.decode([NotificationLogEntry].self, from: data)
            #if DEBUG
            print("📖 NotificationLogStore: Loaded \(entries.count) entries")
            #endif
        } catch {
            #if DEBUG
            print("❌ NotificationLogStore: Failed to decode entries: \(error)")
            #endif
        }
    }

    private func saveEntries() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(entries)
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
            #if DEBUG
            print("💾 NotificationLogStore: Saved \(entries.count) entries")
            #endif
        } catch {
            #if DEBUG
            print("❌ NotificationLogStore: Failed to encode entries: \(error)")
            #endif
        }
    }
}
