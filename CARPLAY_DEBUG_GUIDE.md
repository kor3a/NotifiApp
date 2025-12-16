# CarPlay Notification Debugging Guide

## The Problem
Your location-based notifications aren't appearing on CarPlay screens when driving, even though they work fine on the iPhone.

## Root Cause Analysis

### Most Likely Issues (in order of probability):

1. **Driving Focus Mode Filtering** (90% likely)
   - CarPlay automatically enables Driving Focus
   - Only "critical" or explicitly allowed notifications break through
   - Your app needs to be in the allowed list OR use critical notifications

2. **App Not Configured for CarPlay Notifications** (60% likely)
   - App may not be whitelisted in Focus settings
   - CarPlay has strict notification policies

3. **Interruption Level Insufficient** (40% likely)
   - `.timeSensitive` may not be enough for CarPlay
   - May need `.critical` for guaranteed delivery

4. **Category Configuration** (30% likely)
   - Some category configurations prevent CarPlay display
   - Your latest approach (removing categoryIdentifier) is on the right track

---

## Debugging Strategy

### Phase 1: Immediate Verification Tests

#### Test 1: Check Focus Mode Settings
**On your iPhone:**
1. Settings → Focus → Driving
2. Check "Allowed Notifications"
3. See if your app (Geolocation_v1.0.0) is in the allowed list
4. If NOT → Add it manually and test

**Expected outcome:** Notifications should appear immediately if this was the issue.

---

#### Test 2: Disable Driving Focus Entirely
**Quick test:**
1. Connect to CarPlay
2. On iPhone: Settings → Focus → Driving → Turn OFF
3. Drive near a store location
4. Check if notification appears on CarPlay

**If this works:** The issue is Focus Mode filtering. Proceed to Phase 2.

---

#### Test 3: Check Notification Settings Detail
**Run this debug code** (add to NotificationManager):
```swift
func debugNotificationSettings() {
    notificationCenter.getNotificationSettings { settings in
        print("=== NOTIFICATION SETTINGS DEBUG ===")
        print("Authorization: \(settings.authorizationStatus.rawValue)")
        print("Alert: \(settings.alertSetting.rawValue)")
        print("Sound: \(settings.soundSetting.rawValue)")
        print("Badge: \(settings.badgeSetting.rawValue)")
        print("CarPlay: \(settings.carPlaySetting.rawValue)")
        print("Critical Alert: \(settings.criticalAlertSetting.rawValue)")
        print("TimeSensitive: \(settings.timeSensitiveSetting.rawValue)")
        print("Announcement: \(settings.announcementSetting.rawValue)")
        print("==================================")
    }
}
```

**Call this on app launch** and check console output.

---

### Phase 2: Code Modifications to Test

#### Modification 1: Use Critical Interruption Level
Critical notifications bypass Focus modes entirely (including Driving Focus).

**Change in NotificationManager.swift:92:**
```swift
// Before:
content.interruptionLevel = .timeSensitive

// After:
content.interruptionLevel = .critical
content.sound = .defaultCritical
```

**IMPORTANT:** Critical notifications require special entitlement from Apple for production. Use only for testing.

---

#### Modification 2: Request Critical Alert Permission
**Update requestAuthorization() on line 43:**
```swift
func requestAuthorization() async -> Bool {
    do {
        let granted = try await notificationCenter.requestAuthorization(
            options: [.alert, .sound, .badge, .criticalAlert]
        )
        await MainActor.run {
            isAuthorized = granted
        }
        return granted
    } catch {
        print("Error requesting notification authorization: \(error)")
        return false
    }
}
```

---

#### Modification 3: Add CarPlay-Specific Category Options
**Update registerNotificationCategories() on line 28:**
```swift
private func registerNotificationCategories() {
    let category = UNNotificationCategory(
        identifier: "STORE_PROXIMITY",
        actions: [],
        intentIdentifiers: [],
        options: [.allowInCarPlay, .allowAnnouncement]
    )

    notificationCenter.setNotificationCategories([category])
    print("✅ Registered notification categories with CarPlay support")
}
```

---

#### Modification 4: Remove Category Entirely (Simplest Test)
Your latest commit tried this. Let's verify it's properly implemented:

**In NotificationManager.swift:92, comment out:**
```swift
// content.categoryIdentifier = "STORE_PROXIMITY"
```

And simplify category registration:
```swift
private func registerNotificationCategories() {
    // No categories - let system handle everything
    notificationCenter.setNotificationCategories([])
    print("✅ Using default notification handling (no custom categories)")
}
```

---

### Phase 3: Advanced Debugging

#### Debug 1: Live Notification Monitoring
Add this method to track notification lifecycle:

```swift
func monitorNotificationDelivery(identifier: String) {
    // Check if it's pending
    notificationCenter.getPendingNotificationRequests { requests in
        let pending = requests.filter { $0.identifier == identifier }
        print("📋 Pending notifications matching '\(identifier)': \(pending.count)")
    }

    // Check if it was delivered
    notificationCenter.getDeliveredNotifications { notifications in
        let delivered = notifications.filter { $0.request.identifier == identifier }
        print("📬 Delivered notifications matching '\(identifier)': \(delivered.count)")
    }
}
```

Call this 5 seconds after scheduling a notification to verify delivery.

---

#### Debug 2: CarPlay Connection Detection
Add this to verify CarPlay is connected:

```swift
import CarPlay

class CarPlayMonitor: NSObject, ObservableObject {
    @Published var isConnected = false

    override init() {
        super.init()
        checkCarPlayConnection()
    }

    func checkCarPlayConnection() {
        // Check if any screen is CarPlay
        let carPlayConnected = UIScreen.screens.contains { screen in
            screen.traitCollection.userInterfaceIdiom == .carPlay
        }

        DispatchQueue.main.async {
            self.isConnected = carPlayConnected
            print("🚗 CarPlay connected: \(carPlayConnected)")
        }
    }
}
```

---

#### Debug 3: Notification History Log
Check your existing NotificationLogView to verify notifications ARE being sent:

**Location:** `/Geolocation_v1.0.0/Views/NotificationLogView.swift`

- Open the app
- Tap the bell icon in HomeView
- Verify entries exist when you're near stores

**If logs show notifications sent but CarPlay doesn't display them:**
→ Confirms it's a CarPlay filtering issue, not a sending issue

---

### Phase 4: CarPlay-Specific Implementation (Advanced)

If nothing above works, you may need a proper CarPlay app integration:

#### Option A: Add CarPlay Scene Delegate
Create a dedicated CarPlay scene to handle notifications.

#### Option B: Notification Service Extension
Create an extension that modifies notifications before delivery to enhance CarPlay compatibility.

#### Option C: Use Communication Notifications
Your commit `cfdc55a` tried this. It's worth revisiting with proper implementation:

```swift
import Intents

// In NotificationManager
content.threadIdentifier = "store-reminders"
content.targetContentIdentifier = storeName

// Create intent for communication notification
let intent = INSendMessageIntent(
    recipients: nil,
    outgoingMessageType: .outgoingMessageText,
    content: content.body,
    speakableGroupName: INSpeakableString(spokenPhrase: "Store Reminders"),
    conversationIdentifier: "store-reminders",
    serviceName: nil,
    sender: nil,
    attachments: nil
)

let interaction = INInteraction(intent: intent, response: nil)
interaction.direction = .incoming

interaction.donate { error in
    if let error = error {
        print("Error donating interaction: \(error)")
    }
}
```

---

## Systematic Testing Protocol

### Test Sequence:
1. **Baseline Test** (current code)
   - Connect to CarPlay
   - Drive near test store
   - Note: Does notification appear? ❌ NO

2. **Test: Focus Mode OFF**
   - Disable Driving Focus
   - Drive near test store
   - Note: Does notification appear? Expected: ✅ YES
   - If YES → Issue confirmed as Focus Mode filtering

3. **Test: Add App to Focus Allow List**
   - Re-enable Driving Focus
   - Add app to allowed apps
   - Drive near test store
   - Note: Does notification appear? Expected: ✅ YES

4. **Test: Critical Interruption Level**
   - Use `.critical` interruption
   - Drive near test store
   - Note: Does notification appear? Expected: ✅ YES
   - Note: Bypasses all Focus modes

5. **Test: Remove Category**
   - Comment out categoryIdentifier
   - Remove category registration
   - Drive near test store
   - Note: Does notification appear?

6. **Test: CarPlay Category Options**
   - Add `.allowInCarPlay` option
   - Drive near test store
   - Note: Does notification appear?

---

## Expected Findings

### If Focus Mode OFF works but ON doesn't:
**Solution:** Guide users to add your app to Driving Focus allowed apps in Settings.

### If Critical notifications work:
**Solution:** Request critical notification entitlement from Apple for production use.

### If removing category works:
**Solution:** Keep notifications simple without custom categories.

### If nothing works:
**Next steps:**
- Check Info.plist for CarPlay configuration
- Verify notification appears on iPhone during CarPlay connection
- Check Console app for system logs during notification delivery
- Consider implementing proper CarPlay template app

---

## Info.plist Additions to Try

Add to `/Geolocation_v1.0.0/Info.plist`:

```xml
<key>UIBackgroundModes</key>
<array>
    <string>location</string>
    <string>remote-notification</string>
</array>

<key>NSUserNotificationAlertStyle</key>
<string>alert</string>
```

---

## Console Logging Strategy

### On Mac with iPhone connected:
1. Open Console.app
2. Connect iPhone
3. Filter by process: "UserNotificationCenter"
4. Trigger notification
5. Look for:
   - "Notification request added"
   - "Notification delivered"
   - "Notification suppressed by Focus"
   - "CarPlay notification policy"

### Key log patterns to search for:
- `UNUserNotificationCenter`
- `CarPlay`
- `Focus`
- `DNDMode` (Do Not Disturb)
- Your app bundle ID

---

## Quick Win Checklist

Try these in order for fastest resolution:

- [ ] Turn off Driving Focus and test
- [ ] Add app to Driving Focus allowed apps
- [ ] Check NotificationLogView confirms notifications are being sent
- [ ] Comment out `categoryIdentifier` line
- [ ] Change to `.critical` interruption level
- [ ] Add `.criticalAlert` to permission request
- [ ] Check Settings → Notifications → Your App → CarPlay setting
- [ ] Verify notifications appear on iPhone lock screen during CarPlay
- [ ] Check Console.app logs during test
- [ ] Test with different iOS versions if possible

---

## Need More Help?

After running through these tests, note:
1. Which modifications made notifications appear
2. Any error messages in Xcode console
3. Behavior differences between iPhone screen and CarPlay screen
4. iOS version being tested

This information will help identify the exact issue and permanent solution.
