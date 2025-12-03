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
        // Create a category for store proximity notifications as communication
        let category = UNNotificationCategory(
            identifier: "STORE_PROXIMITY",
            actions: [],
            intentIdentifiers: [INSendMessageIntent.className],
            options: [.customDismissAction]
        )

        notificationCenter.setNotificationCategories([category])
        print("✅ Registered notification categories with communication intent")
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

        // First check if we have permission
        notificationCenter.getNotificationSettings { settings in
            print("   Notification authorization: \(settings.authorizationStatus.rawValue)")
            print("   Alert setting: \(settings.alertSetting.rawValue)")
            print("   Sound setting: \(settings.soundSetting.rawValue)")

            guard settings.authorizationStatus == .authorized else {
                print("   ❌ Notifications not authorized!")
                return
            }

            // Create a communication notification using INSendMessageIntent
            // This makes CarPlay treat it as a message-style notification
            let messageBody: String
            if reminderCount == 1 {
                messageBody = "You have 1 reminder waiting for you at this store."
            } else {
                messageBody = "You have \(reminderCount) reminders waiting for you at this store."
            }

            // Create an intent person representing the app/sender
            let senderHandle = INPersonHandle(value: "nearbuy_app", type: .unknown)
            let sender = INPerson(
                personHandle: senderHandle,
                nameComponents: nil,
                displayName: "NearBuy",
                image: nil,
                contactIdentifier: nil,
                customIdentifier: "nearbuy_app"
            )

            // Create the send message intent
            let intent = INSendMessageIntent(
                recipients: nil,
                outgoingMessageType: .outgoingMessageText,
                content: messageBody,
                speakableGroupName: INSpeakableString(spokenPhrase: storeName),
                conversationIdentifier: "store_proximity",
                serviceName: nil,
                sender: sender,
                attachments: nil
            )

            // Set the intent image (optional)
            intent.setImage(INImage(named: "AppIcon"), forParameterNamed: \.sender)

            // Create notification content with the intent
            do {
                let content = try self.createCommunicationNotificationContent(
                    intent: intent,
                    storeName: storeName,
                    messageBody: messageBody
                )

                // Create a unique identifier based on store name and timestamp
                let identifier = "store_proximity_\(storeName)_\(Date().timeIntervalSince1970)"

                // Trigger immediately (for location-based notifications)
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)

                let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

                self.notificationCenter.add(request) { error in
                    if let error = error {
                        print("   ❌ Error scheduling notification: \(error)")
                    } else {
                        print("   ✅ Successfully scheduled communication notification for \(storeName)")
                        // Log the notification event
                        self.logStore.addEntry(storeName: storeName, reminderCount: reminderCount)
                    }
                }
            } catch {
                print("   ❌ Error creating communication notification: \(error)")
            }
        }
    }

    // Helper to create communication notification content
    private func createCommunicationNotificationContent(
        intent: INSendMessageIntent,
        storeName: String,
        messageBody: String
    ) throws -> UNNotificationContent {
        // Create the notification content from the intent
        let content = try UNNotificationContent(
            intent: intent,
            summary: "Location reminder"
        )

        return content
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
