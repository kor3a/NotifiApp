//
//  NotificationLog.swift
//  Geolocation_v1.0.0
//
//  Created by Claude Code
//

import Foundation

struct NotificationLogEntry: Identifiable, Codable {
    let id: String
    let storeName: String
    let reminderCount: Int
    let timestamp: Date

    init(storeName: String, reminderCount: Int) {
        self.id = UUID().uuidString
        self.storeName = storeName
        self.reminderCount = reminderCount
        self.timestamp = Date()
    }

    // Compute relative time string (e.g., "5 minutes ago", "2 hours ago")
    var timeAgoString: String {
        let now = Date()
        let timeInterval = now.timeIntervalSince(timestamp)

        let seconds = Int(timeInterval)
        let minutes = seconds / 60
        let hours = minutes / 60
        let days = hours / 24

        if days > 0 {
            return days == 1 ? "1 day ago" : "\(days) days ago"
        } else if hours > 0 {
            return hours == 1 ? "1 hour ago" : "\(hours) hours ago"
        } else if minutes > 0 {
            return minutes == 1 ? "1 minute ago" : "\(minutes) minutes ago"
        } else {
            return "Just now"
        }
    }
}
