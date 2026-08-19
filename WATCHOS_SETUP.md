# Apple Watch App — Setup & Architecture

The `AllimWatch Watch App` target puts the user's stores on their wrist: open the
app, pick a store, and check items off without taking the phone out.

## Architecture

The watch holds **no Firebase session**. Signing in a second time on a device
with no keyboard isn't a reasonable ask, so the iPhone app stays the source of
truth and the watch acts as a remote control for it, over `WatchConnectivity`.

```
   Apple Watch                             iPhone                    Firestore
┌────────────────┐                  ┌──────────────────────┐
│ WatchDataStore │                  │ StoresViewModel      │──── user_stores ───▶
│                │                  │        │             │
│  store list ◀──┼── appContext ────┼── WatchConnectivity  │
│                │                  │      Manager         │
│  reminders  ◀──┼── sendMessage ───┼──────  │              │──── reminders ────▶
│                │      (reply)     │        │             │
│  check off  ───┼── sendMessage ───┼───▶ ReminderToggle    │──── batch write ──▶
│                │  / transferUserInfo │      Service       │
└────────────────┘                  └──────────────────────┘
```

**Store list** — pushed with `updateApplicationContext` from
`WatchConnectivityManager.updateStores(from:)`, called from every place
`WidgetDataStore.updateWidgetData` is called, so the widget and the watch stay in
step. The system delivers the context even while the watch app is closed, so the
first screen is already filled in when the user raises their wrist.

**Reminders** — pulled per store when the user taps into one. `sendMessage`
background-launches the iPhone app if it isn't running, so this works without
opening anything on the phone. That's also why `WatchConnectivityManager.activate()`
runs from `AppDelegate.application(_:didFinishLaunchingWithOptions:)` rather than
from the SwiftUI scene: an incoming message only reaches the app if the
`WCSession` delegate was set before it arrived. A background launch has no
`StoresViewModel` behind it, so the manager falls back to reading `user_stores`
straight from Firestore.

**Check-off** — the watch flips the row immediately and sends the change to the
phone, which writes it through `ReminderToggleService` — the same code path
`ReminderViewModel.toggleReminder` uses. A watch tap is therefore
indistinguishable in Firestore from a phone tap: same check-off attribution
(`checkedOffAt` / `checkedOffBy` / `checkedOffById`), same out-of-stock clear, and
the same batch fan-out across every linked copy of a shared reminder.

**Out of range** — the watch keeps its last store list and reminders in
`UserDefaults`, so the list still shows. Check-offs made out of range are handed
to `transferUserInfo`, which the system delivers when the two devices are back
together; those rows are marked "Syncing" until they land.

Stores shared with **View Only** permission arrive with `canEdit == false` and
render read-only, rather than offering a checkbox whose write Firestore rules
would reject.

## Files

| File | Role |
| --- | --- |
| `Geolocation_v1.0.0/Services/ReminderToggleService.swift` | The one place that knows how a check-off is written. Used by the phone UI and the watch bridge. |
| `Geolocation_v1.0.0/Services/WatchSyncModels.swift` | Wire format (payload structs + message keys). |
| `Geolocation_v1.0.0/Services/WatchConnectivityManager.swift` | Phone side: pushes stores, serves reminder requests, applies check-offs. |
| `AllimWatch Watch App/WatchSyncModels.swift` | **Mirror** of the wire format. Edit together with the iOS copy. |
| `AllimWatch Watch App/WatchDataStore.swift` | Watch side: session, state, offline cache. |
| `AllimWatch Watch App/WatchStoreListView.swift` | Store list. |
| `AllimWatch Watch App/WatchReminderListView.swift` | One store's items, with check-off. |

`WatchSyncModels.swift` exists twice because the watch target cannot see the iOS
target's sources — the same arrangement `WidgetStoreData` already uses for the
widget extension. **Changing a property name in one copy without the other
silently breaks decoding on the watch.**

## Xcode target

The target is already in `project.pbxproj` — no need to add it through Xcode's
template. It is a modern single-target watch app (no separate WatchKit extension):

- Product: `AllimWatch Watch App.app`, bundle ID `com.kor3a.nearbuy.watchkitapp`
- `SDKROOT = watchos`, `TARGETED_DEVICE_FAMILY = 4`, `WATCHOS_DEPLOYMENT_TARGET = 9.0`
- `INFOPLIST_KEY_WKCompanionAppBundleIdentifier = com.kor3a.nearbuy` ties it to the phone app
- Sources come from a `PBXFileSystemSynchronizedRootGroup`, so adding a `.swift`
  file to the folder is enough — no project edit needed
- Embedded into `Allim` by an **Embed Watch Content** copy phase
  (`$(CONTENTS_FOLDER_PATH)/Watch`), with a target dependency so it builds first

### App icon

The watch app has its **own** icon in
`AllimWatch Watch App/Assets.xcassets/AppIcon.appiconset` — it does not inherit
the iPhone app's. The iOS app uses Icon Composer files (`Allim.icon`,
`NotifiApp.icon`, with `ASSETCATALOG_COMPILER_APPICON_NAME = NotifiApp`), which
watchOS does not read; the watch target uses a plain asset catalog with
`ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon`.

A watch app that compiles without an icon **installs nowhere** — the Watch app on
the iPhone reports only "the app could not be installed at this time," with the
real reason visible in `installd` logs. So if you replace the art, check that
`AppIcon.appiconset/Contents.json` actually names the file:

```json
{ "filename": "allimIcon.png", "idiom": "universal", "platform": "watchos", "size": "1024x1024" }
```

Dropping a PNG into the folder without that `filename` key leaves the icon slot
empty, which builds cleanly and then fails to install. The image must be
1024×1024 with **no alpha channel**.

### One-time steps in Xcode

1. **Signing** — the watch app needs its own App ID
   (`com.kor3a.nearbuy.watchkitapp`) in the developer portal. Automatic signing
   creates it on first build; confirm under Signing & Capabilities.
2. **Scheme** — Xcode generates a scheme for the new target the first time the
   project is opened. Run that scheme on a paired watch simulator to test.

The watch target links no Swift packages: it needs no Firebase, no ads SDK, and
no Google Sign-In. Keep it that way — Firebase on watchOS would mean a second
sign-in and a much heavier bundle for no gain.

## Testing

The watch app is only useful against a signed-in phone, so test on a paired
simulator pair (or a real pair) with both apps installed:

1. Sign in on the iPhone and add a store with a few reminders.
2. Launch the watch app — the store list should appear immediately, with the
   outstanding-item count matching the phone.
3. Tap a store, tap an item — the row checks off, and the phone's list should
   reflect it within a second.
4. Check something off on the phone, pull to refresh on the watch — the change
   should come through.
5. For the offline path, turn off the phone's Bluetooth/Wi-Fi: the cached list
   still shows, check-offs mark "Syncing", and they land once the phone is back.

## Known limits

- The watch pulls reminders when a store is opened and on pull-to-refresh; it
  does not hold a live subscription while the screen sits open, so a change made
  on the phone at that moment needs a refresh to appear.
- The watch can check items off but not add, edit, or delete them — those stay on
  the phone.
- There is no complication or Smart Stack widget yet; the store list would suit
  one well as a follow-up.
