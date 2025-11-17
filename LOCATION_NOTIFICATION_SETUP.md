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
