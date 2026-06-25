# App Review Response — Guideline 2.1(a) (Submission 6a2457c8-7089-49ed-8bd4-234e209e013c)

> Paste the text below into the Resolution Center reply for this submission.
> Context for our own records is in the section underneath the reply.

---

## Reply to send in App Store Connect

Hello,

Thank you for the review and for the detailed feedback regarding Guideline 2.1(a).

We want to clarify the scope of the app: Allim does **not** provide any VoIP
calling features. It is a location-reminder app with text and photo messaging
between friends. There is no audio calling, no video calling, and no in-app call
button anywhere in the app.

The reference to "VoIP calling features" came from the CarPlay Communication
capability, which we had enabled. We have **removed the
`com.apple.developer.carplay-communication` entitlement** in this build, since
the app is not a CarPlay calling/messaging template app and does not need that
capability.

To be clear about what remains:

- The app still supports its messaging SiriKit intents (Send a Message, Search
  for Messages, Set Message Attribute), which are used for hands-free message
  replies and for Communication Notifications.
- It does **not** declare or require the "Start a call" (`INStartCallIntent`)
  intent, because the app has no calling functionality.
- Our CarPlay notification banners are unaffected: they are delivered as
  standard Communication Notifications (Time-Sensitive), which do not rely on
  the CarPlay Communication entitlement.

Because the app no longer carries the CarPlay Communication capability and
offers no VoIP calling, the requirement to support CallKit and
`INStartCallIntent` no longer applies.

Please let us know if any further information would be helpful. Thank you again.

---

## Internal notes (do not send)

**Root cause:** The build held `com.apple.developer.carplay-communication`,
which classifies the app as a CarPlay communication app. Apple requires that
category to implement the full communication intent set, including
`INStartCallIntent` + CallKit. The app only ever implemented messaging intents.

**What changed in this build:**

- Removed `com.apple.developer.carplay-communication` from:
  - `AllimRelease.entitlements` (Release)
  - `Geolocation_v1.0.0/Geolocation_v1.0.0.entitlements` (Debug)

**What was intentionally kept (CarPlay notifications still work):**

- `.carPlay` notification authorization option — `NotificationManager.swift`
  (`requestAuthorization`)
- `.allowInCarPlay` on all notification categories — `NotificationManager.swift`
  (`registerNotificationCategories`)
- `com.apple.developer.usernotifications.communication` (Communication
  Notifications)
- `com.apple.developer.usernotifications.time-sensitive` (breaks through CarPlay
  Driving Focus)
- Messaging SiriKit intents in `NearBuyIntents` (`INSendMessageIntent`,
  `INSearchForMessagesIntent`, `INSetMessageAttributeIntent`)

**Before resubmitting:**

1. In the Apple Developer portal, regenerate/refresh the provisioning profiles
   for the app target so they no longer include the CarPlay Communication
   capability (otherwise the build may still be signed as a CarPlay comm app).
2. Bump the build number.
3. On a physical device with CarPlay, confirm message/location notification
   banners still appear on the CarPlay screen after the entitlement removal.
