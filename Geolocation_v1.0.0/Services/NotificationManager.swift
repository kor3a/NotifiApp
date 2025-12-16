//
//  NotificationManager.swift
//  Geolocation_v1.0.0
//
//  Created by Claude Code
//

import Foundation
import UserNotifications
import CoreLocation

class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager()

    @Published var isAuthorized = false
    private let notificationCenter = UNUserNotificationCenter.current()
    private let logStore = NotificationLogStore.shared

    private override init() {
        super.init()
        notificationCenter.delegate = self
        registerNotificationCategories()
        checkAuthorizationStatus()
    }

    // MARK: - Category Registration

    private func registerNotificationCategories() {
        // Create a category for store proximity notifications with CarPlay support
        let category = UNNotificationCategory(
            identifier: "STORE_PROXIMITY",
            actions: [],
            intentIdentifiers: [],
            options: [.customDismissAction, .allowInCarPlay, .allowAnnouncement]
        )

        notificationCenter.setNotificationCategories([category])
        print("✅ Registered notification categories with CarPlay and announcement support")
    }

    // MARK: - Permission Management

    func requestAuthorization() async -> Bool {
        do {

            let granted = try await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge, .carPlay])

            await MainActor.run {
                isAuthorized = granted
            }
            print("📱 Notification authorization granted: \(granted)")
            return granted
        } catch {
            print("Error requesting notification authorization: \(error)")
            return false
        }
    }

    func checkAuthorizationStatus() {
        notificationCenter.getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }

    // MARK: - Debug Methods

    func debugNotificationSettings() {
        notificationCenter.getNotificationSettings { settings in
            print("=== NOTIFICATION SETTINGS DEBUG ===")
            print("Authorization: \(settings.authorizationStatus.rawValue)")
            print("Alert: \(settings.alertSetting.rawValue)")
            print("Sound: \(settings.soundSetting.rawValue)")
            print("Badge: \(settings.badgeSetting.rawValue)")
            print("CarPlay: \(settings.carPlaySetting.rawValue)")
            print("Critical Alert: \(settings.criticalAlertSetting.rawValue)")
            print("TimeSensitive: \(settings.timeSensitiveSetting.rawValue)")
            print("Announcement: \(settings.announcementSetting.rawValue)")
            print("==================================")
        }
    }

    // MARK: - Notification Scheduling

    func scheduleStoreProximityNotification(storeName: String, reminderCount: Int) {
        print("🔔 NotificationManager: Attempting to schedule notification for \(storeName)")

        // First check if we have permission
        notificationCenter.getNotificationSettings { settings in
            print("   Notification authorization: \(settings.authorizationStatus.rawValue)")
            print("   Alert setting: \(settings.alertSetting.rawValue)")
            print("   Sound setting: \(settings.soundSetting.rawValue)")

            guard settings.authorizationStatus == .authorized else {
                print("   ❌ Notifications not authorized!")
                return
            }

            let content = UNMutableNotificationContent()
            content.title = "📍 You're near \(storeName)"

            if reminderCount == 1 {
                content.body = "You have 1 reminder waiting for you at this store."
            } else {
                content.body = "You have \(reminderCount) reminders waiting for you at this store."
            }

            content.sound = .default
            content.interruptionLevel = .timeSensitive
            content.relevanceScore = 1.0 // Highest relevance for location-based reminders
            content.categoryIdentifier = "STORE_PROXIMITY"

            // Create a unique identifier based on store name and timestamp
            let identifier = "store_proximity_\(storeName)_\(Date().timeIntervalSince1970)"

            // Trigger immediately (for location-based notifications)
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)

            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

            self.notificationCenter.add(request) { error in
                if let error = error {
                    print("   ❌ Error scheduling notification: \(error)")
                } else {
                    print("   ✅ Successfully scheduled notification for \(storeName)")
                    // Log the notification event
                    self.logStore.addEntry(storeName: storeName, reminderCount: reminderCount)
                }
            }
        }
    }

    // MARK: - Notification Management

    func removeAllPendingNotifications() {
        notificationCenter.removeAllPendingNotificationRequests()
    }

    func removePendingNotifications(withIdentifierPrefix prefix: String) {
        notificationCenter.getPendingNotificationRequests { requests in
            let identifiersToRemove = requests
                .filter { $0.identifier.hasPrefix(prefix) }
                .map { $0.identifier }

            self.notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiersToRemove)
        }
    }

    func getPendingNotifications() async -> [UNNotificationRequest] {
        return await notificationCenter.pendingNotificationRequests()
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationManager: UNUserNotificationCenterDelegate {
    // Handle notification when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                              willPresent notification: UNNotification,
                              withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show notification even when app is in foreground
        // .list ensures it appears in Notification Center and lock screen
        completionHandler([.banner, .list, .sound, .badge])
    }

    // Handle notification tap
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                              didReceive response: UNNotificationResponse,
                              withCompletionHandler completionHandler: @escaping () -> Void) {
        // Handle notification tap - could navigate to store's reminders
        print("User tapped notification: \(response.notification.request.identifier)")
        completionHandler()
    }
}
