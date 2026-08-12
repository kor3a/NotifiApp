# Location-Based Notification Setup

## Required Permissions Configuration

Since this is a SwiftUI project, you need to add the following permissions through **Xcode's project settings**:

### Steps to Add Permissions:

1. Open the project in Xcode
2. Select your app target (Geolocation_v1.0.0)
3. Go to the **Info** tab
4. Add the following keys by clicking the **+** button:

#### Location Permissions

**Key:** `NSLocationAlwaysAndWhenInUseUsageDescription`
**Type:** String
**Value:** `We need your location to notify you when you're near stores with pending reminders.`

**Key:** `NSLocationWhenInUseUsageDescription`
**Type:** String
**Value:** `We need your location to show you stores on the map and notify you about nearby reminders.`

#### Background Modes

1. Go to **Signing & Capabilities** tab
2. Click **+ Capability**
3. Add **Background Modes**
4. Check the following options:
   - ✅ Location updates
   - ✅ Background fetch

## How It Works

1. **Location Monitoring**: The app tracks your location in the background using `LocationMonitoringManager`
2. **Distance Calculation**: Every time your location updates (approximately every 100 meters), the app calculates the distance to all your stores
3. **Notification Trigger**: When you're within 1km (1000 meters) of a store with incomplete reminders, you'll receive a notification
4. **Cooldown Period**: To avoid spam, each store has a 1-hour cooldown period between notifications

## Permission Onboarding

New accounts are asked for both permissions from their own screens rather than
by a silent request on first launch, so the one-shot iOS prompts arrive with an
explanation attached.

Order, for a brand-new account: sign up → username and name → **Enable Location
Services** → **Turn On Notifications** → tutorial → Stores.

- `PermissionOnboardingManager` decides whether the walkthrough runs. A step is
  only included while its system prompt can still appear (`.notDetermined`), so
  anyone who has already answered — including existing users updating into this
  build — goes straight into the app.
- `PermissionOnboardingView` renders the two primers. The button at the bottom of
  each is what triggers the real iOS dialog; answering it (grant *or* deny) moves
  the walkthrough on, since iOS won't ask a second time either way.
- Completion is recorded per Auth UID under
  `hasCompletedPermissionOnboarding_auth_<uid>`.
- `MainView` routes on `PermissionOnboardingManager.shared.state`, between profile
  setup and `HomeView`.
- DEBUG builds have a **Replay Permission Screens** button in Profile. It replays
  the screens only — the system prompts behind them remain one-shot per install.

## Usage

The location monitoring will automatically start when:
- You're logged in
- You've granted "Always Allow" location permission
- You've granted notification permission

You can check the status of permissions in the app's Profile view.

## Privacy Note

- Location data is only used locally on your device to calculate distances
- No location data is sent to or stored in the cloud
- You can disable location monitoring at any time through iOS Settings
