//
//  DEBUG_NotificationManager.swift
//  Enhanced version with comprehensive CarPlay debugging
//
//  USAGE: Temporarily replace NotificationManager.swift with this file
//  to enable advanced debugging capabilities
//

import Foundation
import UserNotifications
import CoreLocation
import UIKit

class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager()

    @Published var isAuthorized = false
    @Published var debugInfo: String = ""
    private let notificationCenter = UNUserNotificationCenter.current()
    private let logStore = NotificationLogStore.shared

    // Debug: Track CarPlay connection
    @Published var isCarPlayConnected = false

    private override init() {
        super.init()
        notificationCenter.delegate = self
        registerNotificationCategories()
        checkAuthorizationStatus()
        startCarPlayMonitoring()
    }

    // MARK: - CarPlay Monitoring

    private func startCarPlayMonitoring() {
        // Check initial state
        checkCarPlayConnection()

        // Monitor for changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenDidConnect),
            name: UIScreen.didConnectNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenDidDisconnect),
            name: UIScreen.didDisconnectNotification,
            object: nil
        )
    }

    @objc private func screenDidConnect(_ notification: Notification) {
        checkCarPlayConnection()
    }

    @objc private func screenDidDisconnect(_ notification: Notification) {
        checkCarPlayConnection()
    }

    private func checkCarPlayConnection() {
        let connected = UIScreen.screens.contains { screen in
            screen.traitCollection.userInterfaceIdiom == .carPlay
        }

        DispatchQueue.main.async {
            self.isCarPlayConnected = connected
            #if DEBUG
            print("🚗 CarPlay Status: \(connected ? "CONNECTED" : "DISCONNECTED")")
            #endif
        }
    }

    // MARK: - Category Registration

    private func registerNotificationCategories() {
        // OPTION 1: Full CarPlay support (default)
        let category = UNNotificationCategory(
            identifier: "STORE_PROXIMITY",
            actions: [],
            intentIdentifiers: [],
            options: [.allowInCarPlay, .allowAnnouncement]
        )

        notificationCenter.setNotificationCategories([category])
        #if DEBUG
        print("✅ Registered notification categories with CarPlay support")
        #endif

        // OPTION 2: No categories (uncomment to test)
        // notificationCenter.setNotificationCategories([])
        // print("✅ Using default notification handling (no custom categories)")
    }

    // MARK: - Permission Management

    func requestAuthorization() async -> Bool {
        do {
            // Request with critical alerts for testing
            // WARNING: criticalAlert requires special entitlement from Apple
            let granted = try await notificationCenter.requestAuthorization(
                options: [.alert, .sound, .badge, .criticalAlert, .announcement]
            )
            await MainActor.run {
                isAuthorized = granted
            }

            // Print detailed settings after authorization
            await printDetailedSettings()

            return granted
        } catch {
            #if DEBUG
            print("Error requesting notification authorization: \(error)")
            #endif
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

    func printDetailedSettings() async {
        let settings = await notificationCenter.notificationSettings()

        let info = """

        ======================================
        📱 NOTIFICATION SETTINGS DEBUG
        ======================================
        Authorization: \(authStatusString(settings.authorizationStatus))
        Alert: \(settingString(settings.alertSetting))
        Sound: \(settingString(settings.soundSetting))
        Badge: \(settingString(settings.badgeSetting))
        CarPlay: \(settingString(settings.carPlaySetting))
        Critical Alert: \(settingString(settings.criticalAlertSetting))
        Time Sensitive: \(settingString(settings.timeSensitiveSetting))
        Announcement: \(settingString(settings.announcementSetting))
        Notification Center: \(settingString(settings.notificationCenterSetting))
        Lock Screen: \(settingString(settings.lockScreenSetting))

        🚗 CarPlay Connected: \(isCarPlayConnected ? "YES" : "NO")
        ======================================

        """

        #if DEBUG
        print(info)
        #endif

        await MainActor.run {
            self.debugInfo = info
        }
    }

    private func authStatusString(_ status: UNAuthorizationStatus) -> String {
        switch status {
        case .notDetermined: return "Not Determined"
        case .denied: return "❌ DENIED"
        case .authorized: return "✅ Authorized"
        case .provisional: return "⚠️ Provisional"
        case .ephemeral: return "Ephemeral"
        @unknown default: return "Unknown"
        }
    }

    private func settingString(_ setting: UNNotificationSetting) -> String {
        switch setting {
        case .notSupported: return "Not Supported"
        case .disabled: return "❌ Disabled"
        case .enabled: return "✅ Enabled"
        @unknown default: return "Unknown"
        }
    }

    func monitorNotificationDelivery(identifier: String) {
        // Check pending after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.notificationCenter.getPendingNotificationRequests { requests in
                let pending = requests.filter { $0.identifier.contains(identifier) }
                #if DEBUG
                print("📋 Pending notifications for '\(identifier)': \(pending.count)")
                for req in pending {
                    print("   - \(req.identifier)")
                }
                #endif
            }
        }

        // Check delivered after 5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            self.notificationCenter.getDeliveredNotifications { notifications in
                let delivered = notifications.filter { $0.request.identifier.contains(identifier) }
                #if DEBUG
                print("📬 Delivered notifications for '\(identifier)': \(delivered.count)")
                for notif in delivered {
                    print("   - \(notif.request.identifier)")
                    print("     Title: \(notif.request.content.title)")
                    print("     Body: \(notif.request.content.body)")
                }
                #endif
            }
        }
    }

    // MARK: - Notification Scheduling

    enum InterruptionMode: String {
        case passive = "Passive"
        case active = "Active (deprecated)"
        case timeSensitive = "Time Sensitive"
        case critical = "Critical (requires entitlement)"
    }

    func scheduleStoreProximityNotification(
        storeName: String,
        reminderCount: Int,
        mode: InterruptionMode = .critical  // Change this to test different modes
    ) {
        #if DEBUG
        print("🔔 NotificationManager: Attempting to schedule notification for \(storeName)")
        print("   Mode: \(mode.rawValue)")
        #endif

        notificationCenter.getNotificationSettings { settings in
            #if DEBUG
            print("   Notification authorization: \(settings.authorizationStatus.rawValue)")
            print("   Alert setting: \(settings.alertSetting.rawValue)")
            print("   Sound setting: \(settings.soundSetting.rawValue)")
            print("   CarPlay setting: \(settings.carPlaySetting.rawValue)")
            print("   Critical setting: \(settings.criticalAlertSetting.rawValue)")
            #endif

            guard settings.authorizationStatus == .authorized else {
                #if DEBUG
                print("   ❌ Notifications not authorized!")
                #endif
                return
            }

            let content = UNMutableNotificationContent()
            content.title = "📍 You're near \(storeName)"

            if reminderCount == 1 {
                content.body = "You have 1 reminder waiting for you at this store."
            } else {
                content.body = "You have \(reminderCount) reminders waiting for you at this store."
            }

            // Configure based on mode
            switch mode {
            case .passive:
                content.interruptionLevel = .passive
                content.sound = .default

            case .active:
                content.interruptionLevel = .active
                content.sound = .default

            case .timeSensitive:
                content.interruptionLevel = .timeSensitive
                content.sound = .default

            case .critical:
                content.interruptionLevel = .critical
                content.sound = .defaultCritical
            }

            content.relevanceScore = 1.0

            // TEST 1: With category (default)
            content.categoryIdentifier = "STORE_PROXIMITY"

            // TEST 2: Without category (uncomment to test)
            // print("   🧪 Testing WITHOUT category identifier")

            // Additional CarPlay optimizations
            content.threadIdentifier = "store-reminders"
            content.targetContentIdentifier = storeName

            let identifier = "store_proximity_\(storeName)_\(Date().timeIntervalSince1970)"

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

            self.notificationCenter.add(request) { error in
                if let error = error {
                    #if DEBUG
                    print("   ❌ Error scheduling notification: \(error)")
                    #endif
                } else {
                    #if DEBUG
                    print("   ✅ Successfully scheduled notification for \(storeName)")
                    print("   📱 Identifier: \(identifier)")
                    #endif

                    // Log the notification
                    self.logStore.addEntry(storeName: storeName, reminderCount: reminderCount)

                    // Monitor delivery
                    self.monitorNotificationDelivery(identifier: identifier)
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

    // MARK: - Debug UI Helpers

    func getAllPendingNotificationsDebug() {
        notificationCenter.getPendingNotificationRequests { requests in
            #if DEBUG
            print("\n📋 === ALL PENDING NOTIFICATIONS ===")
            print("Total count: \(requests.count)")
            for req in requests {
                print("\nID: \(req.identifier)")
                print("Title: \(req.content.title)")
                print("Body: \(req.content.body)")
                if let trigger = req.trigger as? UNTimeIntervalNotificationTrigger {
                    print("Trigger: \(trigger.timeInterval)s")
                }
            }
            print("=====================================\n")
            #endif
        }
    }

    func getAllDeliveredNotificationsDebug() {
        notificationCenter.getDeliveredNotifications { notifications in
            #if DEBUG
            print("\n📬 === ALL DELIVERED NOTIFICATIONS ===")
            print("Total count: \(notifications.count)")
            for notif in notifications {
                print("\nID: \(notif.request.identifier)")
                print("Title: \(notif.request.content.title)")
                print("Body: \(notif.request.content.body)")
                print("Date: \(notif.date)")
            }
            print("======================================\n")
            #endif
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationManager: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                              willPresent notification: UNNotification,
                              withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        #if DEBUG
        print("🔔 willPresent called for: \(notification.request.identifier)")
        print("   Title: \(notification.request.content.title)")
        print("   CarPlay connected: \(isCarPlayConnected)")
        #endif

        // Show notification even when app is in foreground
        completionHandler([.banner, .list, .sound, .badge])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                              didReceive response: UNNotificationResponse,
                              withCompletionHandler completionHandler: @escaping () -> Void) {
        #if DEBUG
        print("👆 User tapped notification: \(response.notification.request.identifier)")
        print("   Action: \(response.actionIdentifier)")
        #endif
        completionHandler()
    }
}
