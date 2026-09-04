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
        // NOTE: both delivery paths present messages as communication
        // notifications — scheduleNewMessageNotification locally, and the
        // NotifiNotificationService extension for pushes (via INSendMessageIntent,
        // needing aps.mutable-content, set in functions/index.js).
        //
        // `.allowInCarPlay` is kept here, but it does not currently win: a
        // communication notification is routed by CarPlay's messaging rules, which
        // need the carplay-communication entitlement this app no longer holds, so
        // these banners do not reach the CarPlay screen. Dropping the intent would
        // put them back on CarPlay at the cost of the sender-led presentation on the
        // phone — an open trade, not a settled one.
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

    /// Mirrors `UNNotificationSettings.carPlaySetting`, which reports only on the
    /// per-app CarPlay toggle in Settings > Notifications.
    ///
    /// This value is the gate. `notSupported` means iOS is not offering this build
    /// a CarPlay notification setting at all, and no banner reaches the CarPlay
    /// screen — not a plain one with `.allowInCarPlay`, not a communication one.
    /// Both were tested and neither is sufficient on its own.
    ///
    /// What flips it is `com.apple.developer.carplay-communication` on the app
    /// target. Note the option set is frozen at first grant: adding the
    /// entitlement to an existing install changes nothing until the app is
    /// deleted and permission granted again. That inheritance masked its removal
    /// in 1d992eb for two months — the banners kept working on a grant captured
    /// while the entitlement was still present.
    enum CarPlayNotificationStatus {
        case enabled    // Per-app CarPlay toggle exists and is ON
        case disabled   // Per-app CarPlay toggle exists but is OFF
        case notSupported  // iOS exposes no per-app CarPlay toggle for this build
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
                carPlayStatus = "enabled (per-app toggle is on)"
            case .disabled:
                carPlayStatus = "disabled (per-app toggle is off — Settings > Notifications > Allim > CarPlay)"
            case .notSupported:
                carPlayStatus = "notSupported (no per-app CarPlay toggle for this build — does NOT by itself mean banners can't reach CarPlay; the communication-notification path is separate)"
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

    // MARK: - Communication Notifications

    /// The app's own mark, for banners that would otherwise lead with the
    /// system's grey silhouette.
    ///
    /// Read from the App Group container rather than held, so the banner wears
    /// whichever icon the user picked on the App Icons screen — including one
    /// they picked a moment ago, which a cached image would miss. The file is
    /// a few kilobytes and a banner is a rare thing to schedule.
    ///
    /// The shipped teal mark stands in until the first export lands, and
    /// `NotifiNotificationService` reads the same file for message pushes, so
    /// a notification looks like Allim whether the app scheduled it or the
    /// extension rewrote it.
    private static var allimAvatar: INImage? {
        if let data = NotificationAvatarStore.currentAvatarData {
            return INImage(imageData: data)
        }
        guard let data = UIImage(named: "AllimNotificationAvatar")?.pngData() else {
            return nil
        }
        return INImage(imageData: data)
    }

    /// Wraps a notification in an INSendMessageIntent so iOS treats it as a communication
    /// notification: the sender's name and avatar lead the banner instead of the app icon.
    ///
    /// This does NOT decide whether a banner reaches the CarPlay screen, in either
    /// direction — earlier revisions of this comment claimed it both ways and both
    /// were wrong. What gates CarPlay is the carplay-communication entitlement; see
    /// `CarPlayNotificationStatus`. Communication and plain notifications were each
    /// tested with the entitlement absent and neither displayed.
    ///
    /// What this does change is the phone: the sender's name leads the banner, and
    /// `content.title` is replaced by `senderDisplayName`. Store proximity alerts are
    /// scheduled plainly so their title keeps naming the store — CarPlay renders the
    /// title and never the body. Messages use this helper, where sender-led
    /// presentation is the point.
    ///
    /// - Parameter avatar: The image the banner leads with. Passing nil leaves
    ///   iOS to draw its own placeholder for the sender.
    private func scheduleAsCommunicationNotification(
        content: UNMutableNotificationContent,
        identifier: String,
        trigger: UNTimeIntervalNotificationTrigger,
        senderDisplayName: String,
        conversationIdentifier: String,
        avatar: INImage? = nil,
        onScheduled: ((Bool) -> Void)? = nil
    ) {
        let sender = INPerson(
            personHandle: INPersonHandle(value: conversationIdentifier, type: .unknown),
            nameComponents: nil,
            displayName: senderDisplayName,
            image: avatar,
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

            // CarPlay renders the title and the app name, never the body — so the
            // store name has to be in the title or the driver sees nothing useful.
            // The body still carries it too, for the phone.
            let trimmedName = storeName.trimmingCharacters(in: .whitespacesAndNewlines)
            let place = trimmedName.isEmpty ? "this store" : trimmedName
            content.title = "📍 You're near \(place)"

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

            // Scheduled plainly, NOT through scheduleAsCommunicationNotification.
            //
            // The proximity banner reaches the CarPlay screen because STORE_PROXIMITY
            // carries `.allowInCarPlay`. Wrapping it in an INSendMessageIntent takes
            // that route away: iOS reclassifies it as a message, and CarPlay then
            // applies its messaging rules, which need the carplay-communication
            // entitlement this app no longer holds. The intent also overwrites the
            // title with the sender name, so the one field CarPlay does render
            // stopped naming the store.
            //
            // Verified against two banners for the same store: a plain one showed
            // "📍 You're near Starbucks Coffee C… / Allim" on the CarPlay screen,
            // while the communication version showed "Allim" on the phone and never
            // reached CarPlay at all.
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            self.notificationCenter.add(request) { addError in
                let scheduled = addError == nil
                #if DEBUG
                if let addError {
                    print("   ❌ Error scheduling proximity notification: \(addError)")
                } else {
                    print("   ✅ Scheduled CarPlay-eligible proximity notification — id=\(identifier)")
                }
                #endif
                if scheduled {
                    self.logStore.addEntry(storeName: storeName, reminderCount: reminderCount)
                }
                onScheduled?(scheduled)
            }
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
                conversationIdentifier: "on-my-way-\(storeName)",
                avatar: Self.allimAvatar
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
