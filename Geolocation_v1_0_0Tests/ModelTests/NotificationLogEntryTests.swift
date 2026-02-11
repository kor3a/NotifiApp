//
//  NotificationLogEntryTests.swift
//  Geolocation_v1_0_0Tests
//

import XCTest
@testable import Allim

final class NotificationLogEntryTests: XCTestCase {

    // MARK: - Initialization

    func testInit_setsDefaultValues() {
        let entry = NotificationLogEntry(storeName: "Walmart", reminderCount: 3)

        XCTAssertEqual(entry.storeName, "Walmart")
        XCTAssertEqual(entry.reminderCount, 3)
        XCTAssertFalse(entry.id.isEmpty)
    }

    func testInit_generatesUniqueIds() {
        let entry1 = NotificationLogEntry(storeName: "Walmart", reminderCount: 1)
        let entry2 = NotificationLogEntry(storeName: "Walmart", reminderCount: 1)
        XCTAssertNotEqual(entry1.id, entry2.id)
    }

    // MARK: - timeAgoString

    func testTimeAgoString_justNow() {
        // Entry created just now should say "Just now"
        let entry = NotificationLogEntry(storeName: "Target", reminderCount: 1)
        XCTAssertEqual(entry.timeAgoString, "Just now")
    }

    func testTimeAgoString_minutesAgo() {
        // Create an entry with a timestamp 5 minutes in the past
        let entry = makeEntryWithTimestamp(minutesAgo: 5)
        XCTAssertEqual(entry.timeAgoString, "5 minutes ago")
    }

    func testTimeAgoString_oneMinuteAgo() {
        let entry = makeEntryWithTimestamp(minutesAgo: 1)
        XCTAssertEqual(entry.timeAgoString, "1 minute ago")
    }

    func testTimeAgoString_hoursAgo() {
        let entry = makeEntryWithTimestamp(hoursAgo: 3)
        XCTAssertEqual(entry.timeAgoString, "3 hours ago")
    }

    func testTimeAgoString_oneHourAgo() {
        let entry = makeEntryWithTimestamp(hoursAgo: 1)
        XCTAssertEqual(entry.timeAgoString, "1 hour ago")
    }

    func testTimeAgoString_daysAgo() {
        let entry = makeEntryWithTimestamp(daysAgo: 2)
        XCTAssertEqual(entry.timeAgoString, "2 days ago")
    }

    func testTimeAgoString_oneDayAgo() {
        let entry = makeEntryWithTimestamp(daysAgo: 1)
        XCTAssertEqual(entry.timeAgoString, "1 day ago")
    }

    // MARK: - Codable

    func testCodable_roundTrip() throws {
        let entry = NotificationLogEntry(storeName: "Costco", reminderCount: 5)
        let data = try JSONEncoder().encode(entry)
        let decoded = try JSONDecoder().decode(NotificationLogEntry.self, from: data)

        XCTAssertEqual(decoded.id, entry.id)
        XCTAssertEqual(decoded.storeName, entry.storeName)
        XCTAssertEqual(decoded.reminderCount, entry.reminderCount)
    }

    // MARK: - Helpers

    /// Creates a NotificationLogEntry with a timestamp set to a specific time in the past.
    /// Uses JSON encoding/decoding to set a custom timestamp since the initializer always uses Date().
    private func makeEntryWithTimestamp(minutesAgo: Int = 0, hoursAgo: Int = 0, daysAgo: Int = 0) -> NotificationLogEntry {
        let totalSeconds = TimeInterval(minutesAgo * 60 + hoursAgo * 3600 + daysAgo * 86400)
        let pastDate = Date().addingTimeInterval(-totalSeconds)

        // Create entry and override timestamp via Codable
        let entry = NotificationLogEntry(storeName: "Test", reminderCount: 1)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        guard var data = try? encoder.encode(entry),
              var json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return entry
        }

        // Replace timestamp with our custom date
        let formatter = ISO8601DateFormatter()
        json["timestamp"] = formatter.string(from: pastDate)

        guard let modifiedData = try? JSONSerialization.data(withJSONObject: json),
              let modifiedEntry = try? JSONDecoder().decode(NotificationLogEntry.self, from: modifiedData) else {
            // Fallback: try direct date manipulation through Codable
            return entry
        }

        return modifiedEntry
    }
}
