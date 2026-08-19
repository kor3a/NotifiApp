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
import UIKit
import AVFoundation

class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager()

    enum NotificationNavigation: Equatable {
        case store(name: String)
        case message(conversationId: String)
        case friendRequest
    }

    enum InterruptionMode: String {
        case passive = "Passive"
        case timeSensitive = "Time Sensitive"
        case critical = "Critical"
    }

    #if DEBUG
    @Published var isCarPlayConnected = false
    @Published var debugInfo: String = ""
    #endif

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
        #if DEBUG
        startCarPlayMonitoring()
        #endif
    }

    #if DEBUG
    private func startCarPlayMonitoring() {
        // Communication-type CarPlay apps don't get a CarPlay UIScreen, so
        // UIScreen.screens / userInterfaceIdiom == .carPlay never matches.
        // Detect via the audio session route instead — when CarPlay is
        // connected, the system adds a `.carAudio` output port to the
        // current route.
        updateCarPlayConnection()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(audioRouteChanged),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
    }

    @objc private func audioRouteChanged(_: Notification) { updateCarPlayConnection() }

    private func updateCarPlayConnection() {
        let outputs = AVAudioSession.sharedInstance().currentRoute.outputs
        let connected = outputs.contains { $0.portType == .carAudio }
        DispatchQueue.main.async { self.isCarPlayConnected = connected }
    }

    func printDetailedSettings() async {
        let settings = await notificationCenter.notificationSettings()
        let info = """
        Authorization: \(settings.authorizationStatus.rawValue)
        Alert: \(settings.alertSetting.rawValue)
        Sound: \(settings.soundSetting.rawValue)
        CarPlay: \(settings.carPlaySetting.rawValue)
        TimeSensitive: \(settings.timeSensitiveSetting.rawValue)
        Announcement: \(settings.announcementSetting.rawValue)
        CarPlay Connected: \(isCarPlayConnected)
        """
        print("=== NOTIFICATION SETTINGS ===\n\(info)\n=============================")
        await MainActor.run { self.debugInfo = info }
    }

    func getAllPendingNotificationsDebug() {
        notificationCenter.getPendingNotificationRequests { requests in
            print("📋 Pending (\(requests.count)):")
            requests.forEach { print("  \($0.identifier): \($0.content.title)") }
        }
    }

    func getAllDeliveredNotificationsDebug() {
        notificationCenter.getDeliveredNotifications { notifications in
            print("📬 Delivered (\(notifications.count)):")
            notifications.forEach { print("  \($0.request.identifier): \($0.request.content.title)") }
        }
    }
    #endif

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

        // Create a category for new message notifications.
        //
        // NOTE: message notifications are CarPlay-eligible only because both
        // delivery paths present them as communication notifications, which
        // surface sender/group name on the CarPlay screen — never the message
        // body (Apple forbids showing message contents in CarPlay):
        //  - local path: scheduleAsCommunicationNotification (below)
        //  - remote path: the NotifiNotificationService extension rewrites the
        //    push via INSendMessageIntent (requires aps.mutable-content, set in
        //    functions/index.js)
        // If either path stops producing communication notifications, remove
        // `.allowInCarPlay` here again.
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

    /// The system's current answer for this app. Distinguishes "never asked"
    /// from "asked and declined", which `isAuthorized` alone can't — the
    /// permission primer only shows while the prompt can still appear.
    func authorizationStatus() async -> UNAuthorizationStatus {
        await notificationCenter.notificationSettings().authorizationStatus
    }

    enum CarPlayNotificationStatus {
        case enabled    // Explicit per-app CarPlay toggle exists and is ON
        case disabled   // Per-app CarPlay toggle exists but is OFF
        case notSupported  // CarPlay notifications are NOT available for the app. Usually means the
                           // `.carPlay` authorization option wasn't captured at first grant (iOS
                           // freezes options at the initial grant — delete + reinstall to re-capture),
                           // or the CarPlay entitlement isn't live in the build. NOT a normal/healthy state.
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
                carPlayStatus = "❌ notSupported — CarPlay notifications NOT available. The `.carPlay` option likely wasn't captured at first grant (delete + reinstall to re-capture) or the CarPlay entitlement isn't live."
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
        onScheduled: ((Bool) -> Void)? = nil
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
            let updateOK: Bool
            if error == nil {
                do {
                    finalContent = try content.updating(from: intent)
                    updateOK = true
                } catch {
                    #if DEBUG
                    print("   ⚠️ content.updating(from: intent) threw: \(error)")
                    #endif
                    finalContent = content
                    updateOK = false
                }
            } else {
                #if DEBUG
                print("   ⚠️ INInteraction.donate failed: \(error!)")
                #endif
                finalContent = content
                updateOK = false
            }

            let request = UNNotificationRequest(identifier: identifier, content: finalContent, trigger: trigger)
            self.notificationCenter.add(request) { addError in
                #if DEBUG
                if let addError {
                    print("   ❌ Error scheduling notification: \(addError)")
                } else {
                    // Communication notifications carry filterCriteria after updating(from:)
                    let isCommunication = updateOK ? "✅ communication" : "❌ NOT communication (fell back)"
                    print("   ✅ Scheduled \(isCommunication) notification — id=\(identifier)")
                    print("      sender=\(senderDisplayName) conversationID=\(conversationIdentifier)")
                }
                #endif
                // Outside the DEBUG guard on purpose: callers hold a background
                // task assertion open until this fires, and the notification log
                // is written from here. Both were dead in Release builds while
                // this call sat inside `#if DEBUG`.
                onScheduled?(addError == nil)
            }
        }
    }

    // MARK: - Notification Scheduling

    /// - Parameter onScheduled: Runs once the request has been handed to the
    ///   system, or as soon as it's clear it never will be. A geofence wake
    ///   holds its background task assertion open until this fires — everything
    ///   that makes the banner CarPlay-eligible (the INSendMessageIntent
    ///   donation, `updating(from:)`, the `add`) happens asynchronously after
    ///   this method has already returned.
    func scheduleStoreProximityNotification(
        storeName: String,
        reminderCount: Int,
        mode: InterruptionMode? = nil,
        delay: TimeInterval = 1,
        onScheduled: ((Bool) -> Void)? = nil
    ) {
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
                onScheduled?(false)
                return
            }

            let content = UNMutableNotificationContent()
            content.title = "📍 You're near \(storeName)"

            // The banner is delivered as a communication notification, so iOS
            // replaces the title with the sender name ("Allim") — the store name
            // has to live in the body or the user never sees which store it is.
            let trimmedName = storeName.trimmingCharacters(in: .whitespacesAndNewlines)
            let place = trimmedName.isEmpty ? "this store" : trimmedName

            if reminderCount == 1 {
                content.body = "You have 1 reminder waiting for you at \(place)."
            } else {
                content.body = "You have \(reminderCount) reminders waiting for you at \(place)."
            }

            #if DEBUG
            switch mode ?? .timeSensitive {
            case .passive:        content.interruptionLevel = .passive;       content.sound = .default
            case .timeSensitive:  content.interruptionLevel = .timeSensitive; content.sound = .default
            case .critical:       content.interruptionLevel = .critical;      content.sound = .defaultCritical
            }
            #else
            content.sound = .default
            content.interruptionLevel = .timeSensitive
            #endif
            content.relevanceScore = 1.0
            content.categoryIdentifier = "STORE_PROXIMITY"
            content.userInfo = ["storeName": storeName]

            let identifier = "store_proximity_\(storeName)_\(Date().timeIntervalSince1970)"
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, delay), repeats: false)

            self.scheduleAsCommunicationNotification(
                content: content,
                identifier: identifier,
                trigger: trigger,
                senderDisplayName: "Allim",
                conversationIdentifier: "store-proximity-\(storeName)",
                onScheduled: { scheduled in
                    if scheduled {
                        self.logStore.addEntry(storeName: storeName, reminderCount: reminderCount)
                    }
                    onScheduled?(scheduled)
                }
            )
        }
    }

    func scheduleFriendRequestNotification(fromUserName: String, notificationId: String) {
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

            let identifier = "fr_\(notificationId)"
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

    func scheduleNewMessageNotification(fromUserName: String, messageContent: String, conversationId: String, notificationId: String) {
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

            let identifier = "msg_\(notificationId)"
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

    func scheduleSharedReminderNotification(senderName: String, storeName: String, addedCount: Int, otherChangeCount: Int, notificationId: String) {
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

            let identifier = "shr_\(notificationId)"
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

    func scheduleOnMyWayNotification(senderName: String, storeName: String, travelTimeMinutes: Int, notificationId: String) {
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

            let identifier = "omw_\(notificationId)"
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
        // Cloud Functions always include a "type" key in the FCM data payload
        // (e.g. "message", "friend_request", "on_my_way", "reminder_change").
        // Local notifications scheduled by the Firestore listeners never carry
        // this key.  When the app is active both paths would fire for the same
        // event, so we suppress the remote copy and let the local one show.
        if notification.request.content.userInfo["type"] != nil {
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
            // Remote FCM notifications arrive without a categoryIdentifier but
            // carry a `type` key in userInfo. Map that back onto the same
            // routing keys used by local notifications so taps on background
            // pushes navigate to the store/conversation instead of falling
            // through to the default tab.
            let routingKey: String
            if !categoryIdentifier.isEmpty {
                routingKey = categoryIdentifier
            } else {
                switch userInfo["type"] as? String {
                case "reminder_change": routingKey = "SHARED_REMINDER_CHANGE"
                case "on_my_way":       routingKey = "ON_MY_WAY"
                case "message":         routingKey = "NEW_MESSAGE"
                case "friend_request":  routingKey = "FRIEND_REQUEST"
                default:                routingKey = ""
                }
            }

            switch routingKey {
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
