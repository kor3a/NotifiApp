//
//  NotificationService.swift
//  NotifiNotificationService
//
//  Created by James Jeon on 6/12/26.
//
//  Upgrades incoming *message* and *On My Way* pushes into communication
//  notifications (via INSendMessageIntent) before they are shown.
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
//  (set server-side in functions/index.js for message and On My Way pushes).
//  All other notification types pass straight through untouched.
//
//  WHY ON MY WAY IS HERE
//  ---------------------
//  Not for CarPlay's sake but for the icon: iOS draws a plain push with the
//  app's primary icon, so an On My Way banner ignored whichever icon the
//  recipient picked on the App Icons screen. A communication notification leads
//  with an image this extension supplies instead, which is the mark of the
//  icon they are actually wearing.
//

import Foundation
import UserNotifications
import Intents

final class NotificationService: UNNotificationServiceExtension {

    private var contentHandler: ((UNNotificationContent) -> Void)?
    private var bestAttemptContent: UNMutableNotificationContent?

    /// The App Group the app exports the current icon's mark into. Kept in
    /// step with `NotificationAvatarStore` in the app target, which writes the
    /// file this reads.
    private static let appGroupSuite = "group.com.kor3a.nearbuy"
    private static let avatarFileName = "NotificationAvatar.png"

    /// The avatar iOS draws on the communication notification.
    ///
    /// An `INPerson` carrying no image leaves the banner with the system's
    /// generic placeholder — a grey silhouette that says neither who sent the
    /// message nor which app it came from. The app's own mark stands in, so a
    /// message from Allim looks like Allim on the Lock Screen.
    ///
    /// It is the mark of whichever icon the user picked on the App Icons
    /// screen: this process has no `UIApplication` to ask, so the app exports
    /// the artwork into the shared container and this reads it back. The
    /// bundled teal mark covers the gap before the first export — a fresh
    /// install, or a container this extension can't reach.
    ///
    /// A fixed mark rather than the sender's own photo on purpose: the push
    /// payload carries no avatar URL (see `functions/index.js`), and an
    /// extension has neither the time budget nor a network guarantee to fetch
    /// one before the banner has to be handed back.
    ///
    /// Read per notification rather than held: an extension process outlives a
    /// single push, and a held image would keep drawing the icon the user has
    /// since changed. Failing to load is not an error worth dropping a
    /// notification over — the banner simply falls back to the placeholder it
    /// shows today.
    private static var avatar: INImage? {
        let sharedURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupSuite)?
            .appendingPathComponent(avatarFileName)

        if let sharedURL, let data = try? Data(contentsOf: sharedURL) {
            return INImage(imageData: data)
        }

        guard let url = Bundle.main.url(
            forResource: "AllimNotificationAvatar",
            withExtension: "png"
        ), let data = try? Data(contentsOf: url) else { return nil }

        return INImage(imageData: data)
    }

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

        // Only the pushes that should lead with a person are converted into
        // communication notifications. Everything else is delivered unchanged.
        //
        // On My Way joins messages here so its banner leads with the app's
        // current mark: a plain push is drawn with the icon iOS holds for the
        // app, which is always the primary one, so the recipient's chosen icon
        // never reached it. What this costs is the CarPlay reading — that
        // screen surfaces the sender rather than the title, so it now says who
        // is on their way and not which store.
        let type = (userInfo["type"] as? String) ?? ""
        guard type == "message" || type == "on_my_way" else {
            contentHandler(bestAttemptContent)
            return
        }

        // On My Way has no group form — it is one person heading to one store.
        let isGroup = type == "message" && (userInfo["isGroup"] as? String) == "true"
        // conversationId groups all banners for one thread; fall back to the
        // thread identifier the push already set. On My Way has no id of its
        // own and rides that fallback, which the Cloud Function sets to the
        // same `on-my-way-<store>` string NotificationManager gives the
        // foreground banner, so the two group together.
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
            image: Self.avatar,
            contactIdentifier: nil,
            customIdentifier: conversationId
        )

        let intent = INSendMessageIntent(
            recipients: nil,
            outgoingMessageType: .outgoingMessageText,
            // Intentionally pass no content: the message text must never reach
            // the CarPlay screen, and On My Way follows the same rule rather
            // than carving out an exception. The iPhone preview is preserved on
            // the notification body itself (bestAttemptContent.body), untouched.
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
