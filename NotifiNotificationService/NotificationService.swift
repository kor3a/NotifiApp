//
//  NotificationService.swift
//  NotifiNotificationService
//
//  Created by James Jeon on 6/12/26.
//
//  Upgrades incoming *message* pushes into communication notifications
//  (via INSendMessageIntent) before they are shown.
//
//  WHY THIS EXISTS
//  ---------------
//  Apple's CarPlay guidelines require that the contents of messages are NEVER
//  shown on the CarPlay screen — only information such as the sender or group
//  name. A plain remote push carries the message preview in its body, so it
//  can't be made CarPlay-visible without leaking content.
//
//  By re-donating an INSendMessageIntent here and calling
//  `content.updating(from:)`, the notification becomes a genuine communication
//  notification. iOS then presents it as a sender/avatar banner and, on the
//  CarPlay screen, surfaces only the sender/group name — never the body — while
//  the iPhone still shows the full preview.
//
//  TRIGGERING
//  ----------
//  This extension only runs when the push payload contains `mutable-content: 1`
//  (set server-side in functions/index.js for message pushes). All other
//  notification types pass straight through untouched.
//

import UserNotifications
import Intents

final class NotificationService: UNNotificationServiceExtension {

    private var contentHandler: ((UNNotificationContent) -> Void)?
    private var bestAttemptContent: UNMutableNotificationContent?

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        self.contentHandler = contentHandler
        let mutableContent = request.content.mutableCopy() as? UNMutableNotificationContent
        self.bestAttemptContent = mutableContent

        guard let bestAttemptContent = mutableContent else {
            contentHandler(request.content)
            return
        }

        let userInfo = bestAttemptContent.userInfo

        // Only message notifications are converted into communication
        // notifications. Everything else is delivered unchanged.
        guard (userInfo["type"] as? String) == "message" else {
            contentHandler(bestAttemptContent)
            return
        }

        let isGroup = (userInfo["isGroup"] as? String) == "true"
        // conversationId groups all banners for one thread; fall back to the
        // thread identifier the push already set.
        let conversationId = (userInfo["conversationId"] as? String)
            ?? bestAttemptContent.threadIdentifier
        // The push title already holds the sender name (1:1) or group name
        // (group); the explicit data keys are preferred when present.
        let senderName = (userInfo["senderName"] as? String) ?? bestAttemptContent.title
        let groupName = (userInfo["groupName"] as? String)
        let displayName = isGroup ? (groupName ?? bestAttemptContent.title) : senderName

        let handle = INPersonHandle(value: conversationId, type: .unknown)
        let sender = INPerson(
            personHandle: handle,
            nameComponents: nil,
            displayName: senderName,
            image: nil,
            contactIdentifier: nil,
            customIdentifier: conversationId
        )

        let intent = INSendMessageIntent(
            recipients: nil,
            outgoingMessageType: .outgoingMessageText,
            // Intentionally pass no content: the message text must never reach
            // the CarPlay screen. The iPhone preview is preserved on the
            // notification body itself (bestAttemptContent.body), untouched.
            content: nil,
            speakableGroupName: isGroup ? INSpeakableString(spokenPhrase: displayName) : nil,
            conversationIdentifier: conversationId,
            serviceName: "Allim",
            sender: sender,
            attachments: nil
        )

        let interaction = INInteraction(intent: intent, response: nil)
        interaction.direction = .incoming
        interaction.donate { _ in }

        do {
            let updated = try bestAttemptContent.updating(from: intent)
            contentHandler(updated)
        } catch {
            // If the system can't form a communication notification, deliver the
            // original so the user still gets a banner (on iPhone).
            contentHandler(bestAttemptContent)
        }
    }

    override func serviceExtensionTimeWillExpire() {
        // Called just before the extension is terminated. Deliver the best
        // attempt we have so the notification is never silently dropped.
        if let contentHandler, let bestAttemptContent {
            contentHandler(bestAttemptContent)
        }
    }
}
