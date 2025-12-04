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
        // Create a category for store proximity notifications
        // Using customDismissAction for proper CarPlay handling
        let category = UNNotificationCategory(
            identifier: "TIME_SENSITIVE_CATEGORY",
            actions: [],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )

        notificationCenter.setNotificationCategories([category])
        print("✅ Registered notification categories")
    }

    // MARK: - Permission Management

    func requestAuthorization() async -> Bool {
        do {
            let granted = try await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])
            await MainActor.run {
                isAuthorized = granted
            }
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

    // MARK: - Notification Scheduling

    func scheduleStoreProximityNotification(storeName: String, reminderCount: Int) {
        print("🔔 NotificationManager: Attempting to schedule notification for \(storeName)")

        // Create notification content
        let content = UNMutableNotificationContent()
        content.title = storeName

        if reminderCount == 1 {
            content.body = "You have 1 reminder"
        } else {
            content.body = "You have \(reminderCount) reminders"
        }

        content.sound = .default
        content.categoryIdentifier = "TIME_SENSITIVE_CATEGORY"
        content.interruptionLevel = .timeSensitive

        // Create a unique identifier
        let identifier = "proximity_\(storeName)_\(Date().timeIntervalSince1970)"

        // Trigger immediately
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        notificationCenter.add(request) { [weak self] error in
            if let error = error {
                print("   ❌ Error scheduling notification: \(error)")
            } else {
                print("   ✅ Notification scheduled for \(storeName)")
                self?.logStore.addEntry(storeName: storeName, reminderCount: reminderCount)
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
