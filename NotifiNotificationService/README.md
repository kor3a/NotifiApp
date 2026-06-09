# NotifiNotificationService (Notification Service Extension)

Upgrades incoming **message** push notifications into **communication
notifications** so they can appear on the CarPlay screen showing only the
sender/group name — never the message body — per Apple's CarPlay guidelines.

The Swift/plist/entitlements files here are complete and ready. They are **not
yet added to a build target** because creating an Xcode target also requires
signing/provisioning setup that must be done in Xcode. Follow the runbook below
once, then it's permanent.

---

## What's already done (committed)

- `NotificationService.swift` — the extension logic (re-donates
  `INSendMessageIntent`, calls `content.updating(from:)`).
- `Info.plist` — declares the `com.apple.usernotifications.service` extension point.
- `NotifiNotificationService.entitlements` — communication-notifications entitlement + app group.
- `functions/index.js` — message pushes now send `mutable-content: 1` (so this
  extension runs) plus `senderName` / `groupName` in the data payload.

## Runbook — add the target in Xcode (~2 min)

1. **File ▸ New ▸ Target… ▸ Notification Service Extension.**
   - Product Name: `NotifiNotificationService`
   - Embed in: `Allim`
   - When prompted "Activate scheme?", click **Cancel** (keep the Allim scheme).
2. Xcode creates a new `NotifiNotificationService/` group with its own
   `NotificationService.swift` and `Info.plist`. **Delete those generated two
   files** (Move to Trash) and instead **Add Files…** the three files already in
   this folder (`NotificationService.swift`, `Info.plist`,
   `NotifiNotificationService.entitlements`), making sure **Target Membership =
   NotifiNotificationService**.
   - Alternatively, just paste the contents of this folder's
     `NotificationService.swift` / `Info.plist` over Xcode's generated versions.
3. Select the **NotifiNotificationService** target ▸ **Signing & Capabilities**:
   - Set **Team** = `XT28W79782` (same as the app).
   - **Code Signing Entitlements** build setting → point at
     `NotifiNotificationService/NotifiNotificationService.entitlements`.
   - Add the **App Groups** capability and tick `group.com.kor3a.nearbuy`.
   - The communication-notifications entitlement is already in the entitlements
     file; automatic signing will register the App ID.
4. Set **iOS Deployment Target** to match the app (it currently builds against a
   recent SDK; 15.0+ is required for communication notifications).

## Final step — re-enable CarPlay for messages

Once the extension target builds and runs, message notifications are
communication notifications and are CarPlay-safe (sender-only). Re-add
`.allowInCarPlay` to the `NEW_MESSAGE` category so they actually show on CarPlay:

`Geolocation_v1.0.0/Services/NotificationManager.swift` →
`registerNotificationCategories()` → `newMessageCategory` options:

```swift
options: [.customDismissAction, .allowInCarPlay, .allowAnnouncement]
```

(It is currently registered **without** `.allowInCarPlay` on purpose, so message
content can't leak onto CarPlay until the extension is in place.)

## Deploy the server change

```
cd functions && firebase deploy --only functions
```

## How to verify

- Send a message to a test device that's connected to CarPlay (or the CarPlay
  Simulator). The banner should show the **sender/group name only** — no body.
- On the iPhone lock screen the same notification still shows the full preview.
- Other notification types (store proximity, on-my-way, reminder changes, friend
  requests) are unaffected and continue to show on CarPlay.
