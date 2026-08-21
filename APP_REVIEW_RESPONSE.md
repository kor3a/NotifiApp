# App Review — Guideline 2.1(a) and the CarPlay Communication capability

History, the reply to send if the issue is raised again, and the checks to run
before submitting.

---

## What happened

Submission 6a2457c8-7089-49ed-8bd4-234e209e013c was rejected under Guideline
2.1(a). The reviewer read the app as offering VoIP calling, because the build
carried `com.apple.developer.carplay-communication`, and asked for CallKit and
`INStartCallIntent`.

The capability was removed (1d992eb) and the app shipped. The reasoning recorded
at the time was that CarPlay notifications did not depend on it. **That was
wrong**, and the mistake took two months to surface:

- Proximity banners kept appearing on the CarPlay screen for five weeks after
  the removal, which looked like confirmation.
- They were running on inherited state. iOS freezes the notification
  authorization option set at first grant, and every build in that window
  installed over the top of a grant captured while the entitlement was still
  present. `UNAuthorizationOptions.carPlay` was never re-evaluated.
- The first clean delete-and-reinstall broke the inheritance. Settings >
  Notifications > Allim lost its "Show in CarPlay" row, `carPlaySetting` began
  reporting `notSupported`, and the banners stopped.
- Restoring the entitlement brought the row back immediately. Nothing else did:
  not the notification format, not the category options, not a reinstall.

The last version of this file listed "confirm banners still appear on the
CarPlay screen after the entitlement removal" as a pre-submission step. It was
not done. Doing it would have caught this before shipping.

---

## Reply to send in App Store Connect

> Send this only if review raises the calling question again. If the build is
> approved, nothing needs saying.

Hello,

Thank you for the review. We want to clarify the scope of the app and why it
carries the CarPlay Communication capability.

Allim is a location-based reminder app. It notifies you when you are near a
store where you have items waiting, and it includes text and photo messaging
between friends who share a list.

**Allim has no calling features of any kind.** There is no audio calling, no
video calling, no CallKit integration, no `INStartCallIntent`, and no call
button anywhere in the app. We do not declare the calling intents, because we do
not implement calling.

We use the CarPlay Communication capability for one purpose: so the app's
notifications can appear on the CarPlay screen while the user is driving. Our
messaging SiriKit intents — Send a Message, Search for Messages, Set Message
Attribute — are implemented in the NearBuyIntents extension and are used for
hands-free message handling and for Communication Notifications.

We are aware that this capability covers both messaging and VoIP calling apps.
Allim is a messaging app only. If the capability requires calling support that
we cannot justify implementing in a reminder app, we would appreciate guidance
on the correct capability for a messaging app that needs its notifications to
reach the CarPlay screen.

Thank you.

---

## Internal notes (do not send)

### What the capability actually buys

Only this: iOS offers Settings > Notifications > Allim > **Show in CarPlay**,
and honours `UNAuthorizationOptions.carPlay`. Without it, `carPlaySetting`
reports `notSupported` and no proximity or message banner reaches the CarPlay
screen, regardless of `.allowInCarPlay` on the categories or whether the
notification is sent as a communication notification. Both of those were tested
and neither is sufficient on its own.

### The risk on resubmission

Apple may reject again. `com.apple.developer.carplay-communication` covers
messaging and VoIP calling apps, and a reviewer can read it as a claim to both.
There are two honest ways forward and only one of them is a code change:

1. **Argue messaging-only** (the reply above). Apple's CarPlay guidance requires
   the three messaging intents of a messaging app and CallKit +
   `INStartCallIntent` of a calling app. Allim implements the first set and
   claims nothing from the second. This is the position to take, but it is a
   position, not a guarantee.
2. **Implement calling.** CallKit plus `INStartCallIntent` would satisfy the
   requirement as the reviewer stated it, and means shipping VoIP calling in a
   grocery-list app. Not recommended.

If neither is acceptable, the capability comes back out and the CarPlay banner
is lost. In that case **Announce Notifications** is the remaining in-car
channel: the categories already carry `.allowAnnouncement` and the notifications
are already time-sensitive, so Siri can read them aloud over the car speakers.
The user has to enable it under Settings > Notifications > Announce
Notifications, and it is audio only — no banner.

### What supports the messaging claim in the build

- `NearBuyIntents` declares `INSendMessageIntent`, `INSearchForMessagesIntent`
  and `INSetMessageAttributeIntent`, and `IntentHandler.swift` implements a
  handler for each.
- `AppIntentVocabulary.plist` ships in the app target.
- `NSUserActivityTypes` in Info.plist lists `INSendMessageIntent`.
- `com.apple.developer.siri` is on the app target.
- No calling symbol appears anywhere in the codebase — `INStartCallIntent`,
  `CallKit`, `CXProvider` are all absent.
- The messaging UI is reachable from the Messages tab.

### Before submitting

1. **Verify on a real head unit.** Connect CarPlay, background the app, trigger
   a proximity notification, confirm the banner appears on the CarPlay screen.
   This is the step that was skipped last time. Do not submit without it.
2. Confirm Settings > Notifications > Allim shows **Show in CarPlay**, and that
   the console prints `CarPlay: enabled` rather than `notSupported`.
3. Confirm the CarPlay capability is enabled on the `com.kor3a.nearbuy` App ID
   and that the profile in use includes it.
4. Bump the build number.
5. In App Store Connect review notes, state plainly that the app has no calling
   features and that the CarPlay capability is used for driving notifications,
   so the reviewer meets the explanation before forming a view.
6. Give the reviewer a path to the messaging feature: a demo account with a
   friend already added and a conversation with history, so Messages is not an
   empty screen.
