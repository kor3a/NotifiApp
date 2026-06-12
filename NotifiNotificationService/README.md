# NotifiNotificationService (Notification Service Extension)

Upgrades incoming **message** push notifications into **communication
notifications** so they can appear on the CarPlay screen showing only the
sender/group name — never the message body — per Apple's CarPlay guidelines.

## Status: fully wired ✅

- [x] Xcode target created and embedded in the Allim app (team XT28W79782,
      automatic signing, bundle id `com.kor3a.nearbuy.NotifiNotificationService`).
- [x] `NotificationService.swift` — real implementation (re-donates
      `INSendMessageIntent`, calls `content.updating(from:)`). Non-message
      notification types pass through untouched.
- [x] `CODE_SIGN_ENTITLEMENTS` points at `NotifiNotificationService.entitlements`
      (app group only) for Debug and Release. The Communication Notifications
      capability stays on the **app** target — it's not valid in an extension's
      profile, and the extension produces communication notifications via the
      host app's capability regardless.
- [x] Deployment target 17.5, matching the app and widget.
- [x] `NEW_MESSAGE` category re-registered with `.allowInCarPlay` in
      `NotificationManager.swift` (safe now that both delivery paths are
      communication notifications).
- [x] `functions/index.js` sends `mutable-content: 1` plus `senderName` /
      `groupName` on message pushes so this extension runs.

## Remaining (one-time, outside the repo)

- Deploy the Cloud Functions change: `cd functions && firebase deploy --only functions`
- First build in Xcode: automatic signing will register the new App ID
  `com.kor3a.nearbuy.NotifiNotificationService` and provision the
  communication-notifications entitlement + app group. If signing complains,
  open Signing & Capabilities for this target once so Xcode syncs profiles.

## How to verify

- Send a message to a test device connected to CarPlay (or the CarPlay
  Simulator: Xcode ▸ Open Developer Tool ▸ Simulator, then I/O ▸ External
  Displays ▸ CarPlay). The banner should show the **sender/group name only** —
  no message body.
- On the iPhone lock screen the same notification still shows the full preview.
- Other notification types (store proximity, on-my-way, reminder changes,
  friend requests) are unaffected and continue to show on CarPlay.

## How it works

1. Cloud Function sends an APNs push with `mutable-content: 1` and
   `type: "message"` in the data payload.
2. iOS launches this extension before displaying the notification.
3. The extension builds an `INSendMessageIntent` describing the sender (and
   group, if any), donates it, and calls `content.updating(from: intent)`.
4. The system now treats the notification as a communication notification:
   iPhone shows sender avatar + full preview; CarPlay shows sender/group name
   only. On any error the original content is delivered so banners are never
   dropped.
