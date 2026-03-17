//
//  NotificationManager.swift
//  Geolocation_v1.0.0
//
//  Created by Claude Code
//

import Foundation
import UserNotifications
import CoreLocation
import Intents

class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager()

    enum NotificationNavigation: Equatable {
        case store(name: String)
        case message(conversationId: String)
        case friendRequest
    }

    @Published var isAuthorized = false
    @Published var isCarPlayEnabled = false
    @Published var pendingNavigation: NotificationNavigation? = nil
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
        let storeProximityCategory = UNNotificationCategory(
            identifier: "STORE_PROXIMITY",
            actions: [],
            intentIdentifiers: [],
            options: [.customDismissAction, .allowInCarPlay, .allowAnnouncement]
        )

        // Create a category for friend request notifications
        let friendRequestCategory = UNNotificationCategory(
            identifier: "FRIEND_REQUEST",
            actions: [],
            intentIdentifiers: [],
            options: [.customDismissAction, .allowInCarPlay, .allowAnnouncement]
        )

        // Create a category for new message notifications
        let newMessageCategory = UNNotificationCategory(
            identifier: "NEW_MESSAGE",
            actions: [],
            intentIdentifiers: [],
            options: [.customDismissAction, .allowInCarPlay, .allowAnnouncement]
        )

        // Create a category for shared reminder change notifications
        let sharedReminderCategory = UNNotificationCategory(
            identifier: "SHARED_REMINDER_CHANGE",
            actions: [],
            intentIdentifiers: [],
            options: [.customDismissAction, .allowInCarPlay, .allowAnnouncement]
        )

        // Create a category for "on my way" notifications
        let onMyWayCategory = UNNotificationCategory(
            identifier: "ON_MY_WAY",
            actions: [],
            intentIdentifiers: [],
            options: [.customDismissAction, .allowInCarPlay, .allowAnnouncement]
        )

        notificationCenter.setNotificationCategories([storeProximityCategory, friendRequestCategory, newMessageCategory, sharedReminderCategory, onMyWayCategory])
        #if DEBUG
        print("✅ Registered notification categories with CarPlay and announcement support")
        #endif
    }

    // MARK: - Permission Management

    func requestAuthorization() async -> Bool {
        do {

            let granted = try await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge, .carPlay])

            await MainActor.run {
                isAuthorized = granted
            }
            #if DEBUG
            print("📱 Notification authorization granted: \(granted)")
            #endif
            return granted
        } catch {
            #if DEBUG
            print("Error requesting notification authorization: \(error)")
            #endif
            return false
        }
    }

    enum CarPlayNotificationStatus {
        case enabled    // Explicit per-app CarPlay toggle exists and is ON
        case disabled   // Per-app CarPlay toggle exists but is OFF
        case notSupported  // No per-app toggle — normal for apps without CarPlay entitlement;
                           // notifications still route to CarPlay via .allowInCarPlay category option
    }

    @Published private(set) var _carPlaySetting: CarPlayNotificationStatus = .notSupported

    func checkAuthorizationStatus() {
        notificationCenter.getNotificationSettings { settings in
            let carPlayStatus: CarPlayNotificationStatus
            switch settings.carPlaySetting {
            case .enabled:      carPlayStatus = .enabled
            case .disabled:     carPlayStatus = .disabled
            case .notSupported: carPlayStatus = .notSupported
            @unknown default:   carPlayStatus = .notSupported
            }
            DispatchQueue.main.async {
                self.isAuthorized = settings.authorizationStatus == .authorized
                self.isCarPlayEnabled = settings.carPlaySetting == .enabled
                self._carPlaySetting = carPlayStatus
            }
        }
    }

    // MARK: - Debug Methods

    func debugNotificationSettings() {
        notificationCenter.getNotificationSettings { settings in
            #if DEBUG
            let carPlayStatus: String
            switch settings.carPlaySetting {
            case .enabled:
                carPlayStatus = "✅ ENABLED (per-app toggle is on)"
            case .disabled:
                carPlayStatus = "❌ DISABLED — Go to Settings > Notifications > [App] > CarPlay and turn it on"
            case .notSupported:
                carPlayStatus = "ℹ️ notSupported (expected for apps without CarPlay entitlement — notifications route via .allowInCarPlay category option)"
            @unknown default:
                carPlayStatus = "❓ UNKNOWN (rawValue=\(settings.carPlaySetting.rawValue))"
            }
            print("=== NOTIFICATION SETTINGS DEBUG ===")
            print("Authorization: \(settings.authorizationStatus.rawValue)")
            print("Alert: \(settings.alertSetting.rawValue)")
            print("Sound: \(settings.soundSetting.rawValue)")
            print("Badge: \(settings.badgeSetting.rawValue)")
            print("CarPlay: \(carPlayStatus)")
            print("Critical Alert: \(settings.criticalAlertSetting.rawValue)")
            print("TimeSensitive: \(settings.timeSensitiveSetting.rawValue)")
            print("Announcement: \(settings.announcementSetting.rawValue)")
            print("==================================")
            #endif
        }
    }

    // MARK: - CarPlay-Compatible Scheduling

    /// Wraps a notification in an INSendMessageIntent so iOS treats it as a communication
    /// notification. This is required for reliable CarPlay banner display on apps without
    /// a CarPlay entitlement — generic local notifications are not guaranteed to appear
    /// on the CarPlay screen, but communication notifications are.
    private func scheduleAsCommunicationNotification(
        content: UNMutableNotificationContent,
        identifier: String,
        trigger: UNTimeIntervalNotificationTrigger,
        senderDisplayName: String,
        conversationIdentifier: String,
        onScheduled: (() -> Void)? = nil
    ) {
        let sender = INPerson(
            personHandle: INPersonHandle(value: conversationIdentifier, type: .unknown),
            nameComponents: nil,
            displayName: senderDisplayName,
            image: nil,
            contactIdentifier: nil,
            customIdentifier: conversationIdentifier
        )

        let intent = INSendMessageIntent(
            recipients: nil,
            outgoingMessageType: .outgoingMessageText,
            content: content.body,
            speakableGroupName: INSpeakableString(spokenPhrase: senderDisplayName),
            conversationIdentifier: conversationIdentifier,
            serviceName: "Allim",
            sender: sender,
            attachments: nil
        )

        let interaction = INInteraction(intent: intent, response: nil)
        interaction.direction = .incoming

        interaction.donate { [weak self] error in
            guard let self else { return }

            let finalContent: UNNotificationContent
            if error == nil, let updated = try? content.updating(from: intent) {
                finalContent = updated
            } else {
                finalContent = content
            }

            let request = UNNotificationRequest(identifier: identifier, content: finalContent, trigger: trigger)
            self.notificationCenter.add(request) { addError in
                #if DEBUG
                if let addError {
                    print("   ❌ Error scheduling notification: \(addError)")
                } else {
                    print("   ✅ Scheduled notification")
                    onScheduled?()
                }
                #endif
            }
        }
    }

    // MARK: - Notification Scheduling

    func scheduleStoreProximityNotification(storeName: String, reminderCount: Int) {
        #if DEBUG
        print("🔔 NotificationManager: Attempting to schedule notification for \(storeName)")
        #endif

        // First check if we have permission
        notificationCenter.getNotificationSettings { settings in
            #if DEBUG
            print("   Notification authorization: \(settings.authorizationStatus.rawValue)")
            print("   Alert setting: \(settings.alertSetting.rawValue)")
            print("   Sound setting: \(settings.soundSetting.rawValue)")
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

            content.sound = .default
            content.interruptionLevel = .timeSensitive
            content.relevanceScore = 1.0 // Highest relevance for location-based reminders
            content.categoryIdentifier = "STORE_PROXIMITY"
            content.userInfo = ["storeName": storeName]

            let identifier = "store_proximity_\(storeName)_\(Date().timeIntervalSince1970)"
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)

            self.scheduleAsCommunicationNotification(
                content: content,
                identifier: identifier,
                trigger: trigger,
                senderDisplayName: "Allim",
                conversationIdentifier: "store-proximity-\(storeName)",
                onScheduled: {
                    self.logStore.addEntry(storeName: storeName, reminderCount: reminderCount)
                }
            )
        }
    }

    func scheduleFriendRequestNotification(fromUserName: String) {
        #if DEBUG
        print("🔔 NotificationManager: Attempting to schedule friend request notification from \(fromUserName)")
        #endif

        // First check if we have permission
        notificationCenter.getNotificationSettings { settings in
            #if DEBUG
            print("   Notification authorization: \(settings.authorizationStatus.rawValue)")
            #endif

            guard settings.authorizationStatus == .authorized else {
                #if DEBUG
                print("   ❌ Notifications not authorized!")
                #endif
                return
            }

            let content = UNMutableNotificationContent()
            content.title = "New Friend Request"
            content.body = "\(fromUserName) wants to be your friend."
            content.sound = .default
            content.interruptionLevel = .timeSensitive
            content.relevanceScore = 0.9
            content.categoryIdentifier = "FRIEND_REQUEST"

            let identifier = "friend_request_\(fromUserName)_\(Date().timeIntervalSince1970)"
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)

            self.scheduleAsCommunicationNotification(
                content: content,
                identifier: identifier,
                trigger: trigger,
                senderDisplayName: fromUserName,
                conversationIdentifier: "friend-request-\(fromUserName)"
            )
        }
    }

    func scheduleNewMessageNotification(fromUserName: String, messageContent: String, conversationId: String) {
        #if DEBUG
        print("🔔 NotificationManager: Attempting to schedule new message notification from \(fromUserName)")
        #endif

        // First check if we have permission
        notificationCenter.getNotificationSettings { settings in
            #if DEBUG
            print("   Notification authorization: \(settings.authorizationStatus.rawValue)")
            #endif

            guard settings.authorizationStatus == .authorized else {
                #if DEBUG
                print("   ❌ Notifications not authorized!")
                #endif
                return
            }

            let content = UNMutableNotificationContent()
            content.title = "New Message from \(fromUserName)"

            // Truncate message content if too long
            let truncatedContent = messageContent.count > 100
                ? String(messageContent.prefix(100)) + "..."
                : messageContent
            content.body = truncatedContent

            content.sound = .default
            content.interruptionLevel = .timeSensitive
            content.relevanceScore = 0.95
            content.categoryIdentifier = "NEW_MESSAGE"

            // Add conversation ID to userInfo for navigation on tap
            content.userInfo = ["conversationId": conversationId]

            let identifier = "new_message_\(conversationId)_\(Date().timeIntervalSince1970)"
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)

            self.scheduleAsCommunicationNotification(
                content: content,
                identifier: identifier,
                trigger: trigger,
                senderDisplayName: fromUserName,
                conversationIdentifier: conversationId
            )
        }
    }

    func scheduleSharedReminderNotification(senderName: String, storeName: String, addedCount: Int, otherChangeCount: Int) {
        #if DEBUG
        print("🔔 NotificationManager: Scheduling shared reminder notification from \(senderName) for \(storeName)")
        #endif

        notificationCenter.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else {
                #if DEBUG
                print("   ❌ Notifications not authorized!")
                #endif
                return
            }

            let content = UNMutableNotificationContent()
            content.title = "Shared List Updated"

            // Build a descriptive body based on what changed
            if addedCount > 0 && otherChangeCount > 0 {
                let itemWord = addedCount == 1 ? "item" : "items"
                content.body = "\(senderName) added \(addedCount) \(itemWord) and made changes to the \(storeName) list."
            } else if addedCount > 0 {
                let itemWord = addedCount == 1 ? "item" : "items"
                content.body = "\(senderName) added \(addedCount) \(itemWord) to \(storeName)."
            } else {
                content.body = "\(senderName) updated the \(storeName) list."
            }

            content.sound = .default
            content.interruptionLevel = .timeSensitive
            content.relevanceScore = 0.8
            content.categoryIdentifier = "SHARED_REMINDER_CHANGE"
            content.userInfo = ["storeName": storeName]

            let identifier = "shared_reminder_\(storeName)_\(Date().timeIntervalSince1970)"
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)

            self.scheduleAsCommunicationNotification(
                content: content,
                identifier: identifier,
                trigger: trigger,
                senderDisplayName: senderName,
                conversationIdentifier: "shared-reminder-\(storeName)"
            )
        }
    }

    func scheduleOnMyWayNotification(senderName: String, storeName: String, travelTimeMinutes: Int) {
        #if DEBUG
        print("🔔 NotificationManager: Scheduling on-my-way notification from \(senderName) for \(storeName)")
        #endif

        notificationCenter.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else {
                #if DEBUG
                print("   ❌ Notifications not authorized!")
                #endif
                return
            }

            let content = UNMutableNotificationContent()
            content.title = "🚗 \(senderName) is on their way!"

            if travelTimeMinutes < 60 {
                content.body = "\(senderName) is on their way to \(storeName)! It'll take approximately \(travelTimeMinutes) min to get there."
            } else {
                let hours = travelTimeMinutes / 60
                let minutes = travelTimeMinutes % 60
                if minutes == 0 {
                    content.body = "\(senderName) is on their way to \(storeName)! It'll take approximately \(hours) hr to get there."
                } else {
                    content.body = "\(senderName) is on their way to \(storeName)! It'll take approximately \(hours) hr \(minutes) min to get there."
                }
            }

            content.sound = .default
            content.interruptionLevel = .timeSensitive
            content.relevanceScore = 0.9
            content.categoryIdentifier = "ON_MY_WAY"
            content.userInfo = ["storeName": storeName]

            let identifier = "on_my_way_\(storeName)_\(Date().timeIntervalSince1970)"
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)

            self.scheduleAsCommunicationNotification(
                content: content,
                identifier: identifier,
                trigger: trigger,
                senderDisplayName: senderName,
                conversationIdentifier: "on-my-way-\(storeName)"
            )
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
        let userInfo = notification.request.content.userInfo
        // Suppress FCM push notifications while the app is in the foreground.
        // The Firestore listener already scheduled a local notification for the
        // same event (source == "fcm" is set by the Cloud Function).
        if let source = userInfo["source"] as? String, source == "fcm" {
            completionHandler([])
            return
        }
        // Show local notifications even when app is in foreground.
        // .list ensures it appears in Notification Center and lock screen.
        completionHandler([.banner, .list, .sound, .badge])
    }

    // Handle notification tap
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                              didReceive response: UNNotificationResponse,
                              withCompletionHandler completionHandler: @escaping () -> Void) {
        let categoryIdentifier = response.notification.request.content.categoryIdentifier
        let userInfo = response.notification.request.content.userInfo

        #if DEBUG
        print("User tapped notification: \(response.notification.request.identifier), category: \(categoryIdentifier)")
        #endif

        DispatchQueue.main.async {
            switch categoryIdentifier {
            case "STORE_PROXIMITY", "SHARED_REMINDER_CHANGE", "ON_MY_WAY":
                if let storeName = userInfo["storeName"] as? String {
                    self.pendingNavigation = .store(name: storeName)
                }
            case "NEW_MESSAGE":
                if let conversationId = userInfo["conversationId"] as? String {
                    self.pendingNavigation = .message(conversationId: conversationId)
                }
            case "FRIEND_REQUEST":
                self.pendingNavigation = .friendRequest
            default:
                break
            }
        }

        completionHandler()
    }
}
