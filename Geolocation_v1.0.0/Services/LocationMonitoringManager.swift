//
//  LocationMonitoringManager.swift
//  Geolocation_v1.0.0
//
//  Created by Claude Code
//

import Foundation
import CoreLocation
import Combine
import FirebaseFirestore

class LocationMonitoringManager: NSObject, ObservableObject {
    static let shared = LocationMonitoringManager()

    private let locationManager = CLLocationManager()
    private let db = Firestore.firestore()
    private let notificationManager = NotificationManager.shared

    // Distance threshold in meters (1km = 1000m)
    private let proximityThreshold: CLLocationDistance = 100

    // Geofence radius - must be at least 100m for iOS
    private let geofenceRadius: CLLocationDistance = 150

    // Track recently notified stores to avoid spam (store ID -> last notification time)
    private var recentlyNotifiedStores: [String: Date] = [:]
    private let notificationCooldown: TimeInterval = 3600 // 1 hour cooldown

    // Track active geofences (region identifier -> userStore ID)
    private var activeGeofences: [String: String] = [:]

    @Published var isMonitoring = false
    @Published var lastLocation: CLLocation?

    private var userStores: [UserStore] = []
    private var storeReminders: [String: Int] = [:] // userStoreId -> incomplete reminder count
    private var currentUserId: String? {
        didSet {
            // Persist user ID for background launches
            if let userId = currentUserId {
                UserDefaults.standard.set(userId, forKey: "LocationMonitoring.userId")
            } else {
                UserDefaults.standard.removeObject(forKey: "LocationMonitoring.userId")
            }
        }
    }

    private override init() {
        super.init()
        setupLocationManager()

        // Restore user ID from UserDefaults for background launches
        if let savedUserId = UserDefaults.standard.string(forKey: "LocationMonitoring.userId") {
            currentUserId = savedUserId
            print("🔄 LocationMonitoring: Restored user ID from UserDefaults: \(savedUserId)")

            // Auto-start monitoring if we have permission
            let status = locationManager.authorizationStatus
            if status == .authorizedAlways || status == .authorizedWhenInUse {
                print("   ✅ Auto-starting monitoring (app may have been launched in background)")
                startMonitoring(userId: savedUserId)
            }
        }
    }

    // MARK: - Setup

    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager.distanceFilter = 100 // Update every 100 meters
        // Note: allowsBackgroundLocationUpdates will be set when monitoring starts
        locationManager.pausesLocationUpdatesAutomatically = false
    }

    // MARK: - Permission Management

    func requestLocationPermission() {
        let status = locationManager.authorizationStatus

        switch status {
        case .notDetermined:
            locationManager.requestAlwaysAuthorization()
        case .authorizedWhenInUse:
            locationManager.requestAlwaysAuthorization()
        case .authorizedAlways:
            print("Already have always authorization")
        case .restricted, .denied:
            print("Location permission denied or restricted")
        @unknown default:
            print("Unknown authorization status")
        }
    }

    func checkLocationPermission() -> CLAuthorizationStatus {
        return locationManager.authorizationStatus
    }

    // MARK: - Monitoring Control

    func setUserId(_ userId: String) {
        currentUserId = userId
        print("LocationMonitoring: Set user ID to \(userId)")
    }

    func startMonitoring(userId: String) {
        currentUserId = userId

        print("🔵 LocationMonitoring: startMonitoring called for userId: \(userId)")

        let permission = checkLocationPermission()

        // Accept both "When In Use" and "Always" permissions
        guard permission == .authorizedAlways || permission == .authorizedWhenInUse else {
            print("⚠️ LocationMonitoring: Cannot start monitoring without location permission")
            print("User ID saved - will auto-start when permission is granted")
            return
        }

        if permission == .authorizedWhenInUse {
            print("⚠️ LocationMonitoring: Running with 'When In Use' permission")
            print("   App will monitor location while in use and use significant location changes in background")
            print("   iOS will prompt for 'Always' permission after you use location features a few times")
            // Enable significant location changes for background monitoring with "When In Use" permission
            // This does NOT require allowsBackgroundLocationUpdates or background modes capability
            locationManager.startMonitoringSignificantLocationChanges()
        } else if permission == .authorizedAlways {
            // With "Always" permission, we can use continuous location updates in background
            print("✅ LocationMonitoring: Running with 'Always' permission")
            print("   App will monitor location continuously, even in background")
            // Only enable background location updates with "Always" permission
            locationManager.allowsBackgroundLocationUpdates = true
        }

        isMonitoring = true
        loadUserStores(userId: userId)
        locationManager.startUpdatingLocation()
        print("✅ LocationMonitoring: Started location monitoring successfully")
        print("📱 LocationMonitoring: Desired accuracy: \(locationManager.desiredAccuracy)")
        print("📱 LocationMonitoring: Distance filter: \(locationManager.distanceFilter)m")

        if permission == .authorizedWhenInUse {
            print("📱 LocationMonitoring: Significant location changes: enabled")
        } else if permission == .authorizedAlways {
            print("📱 LocationMonitoring: Background updates: enabled")
        }
    }

    func stopMonitoring() {
        isMonitoring = false
        locationManager.stopUpdatingLocation()
        locationManager.stopMonitoringSignificantLocationChanges()
        removeAllGeofences()
        print("Stopped location monitoring and geofencing")
    }

    // MARK: - Data Loading

    private func loadUserStores(userId: String) {
        print("🔄 LocationMonitoring: Loading user stores for userId: \(userId)")

        db.collection("user_stores")
            .whereField("userId", isEqualTo: userId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }

                if let error = error {
                    print("❌ LocationMonitoring: Error fetching user stores: \(error)")
                    return
                }

                guard let documents = snapshot?.documents else {
                    print("⚠️ LocationMonitoring: No user stores found")
                    return
                }

                // Clear old reminder counts before loading new stores
                self.storeReminders.removeAll()

                self.userStores = documents.compactMap { doc -> UserStore? in
                    do {
                        var userStore = try doc.data(as: UserStore.self)
                        // Manually set the ID from doc.documentID
                        userStore.id = doc.documentID

                        // Only include stores with notifications enabled
                        guard userStore.notificationsEnabled else {
                            print("   ⏸️ Skipping store '\(userStore.storeName)' - notifications disabled")
                            return nil
                        }

                        print("   ✓ Decoded store '\(userStore.storeName)' with ID: \(doc.documentID) - notifications enabled")
                        return userStore
                    } catch {
                        print("❌ LocationMonitoring: Failed to decode store \(doc.documentID): \(error)")
                        return nil
                    }
                }

                print("📦 LocationMonitoring: Loaded \(self.userStores.count) stores for monitoring (notifications enabled)")

                // Log details about each store
                for store in self.userStores {
                    let hasCoords = store.latitude != nil && store.longitude != nil
                    let coordsStr = hasCoords ? "✓ (\(store.latitude!), \(store.longitude!))" : "✗ NO COORDINATES"
                    print("   - \(store.storeName): \(coordsStr)")
                }

                // Load reminder counts for each store
                self.loadReminderCounts()

                // Set up geofences for all stores
                self.setupGeofences()
            }
    }

    private func loadReminderCounts() {
        for userStore in userStores {
            // Skip stores without valid IDs
            guard let userStoreId = userStore.id else {
                print("⚠️ LocationMonitoring: Store '\(userStore.storeName)' has no ID, skipping")
                continue
            }

            // Determine which ID to use for fetching reminders
            // Priority: sourceUserStoreId (view only) > sharedStoreGroupId (can edit) > userStore.id (owner)
            let reminderStoreId = userStore.sourceUserStoreId ?? userStore.sharedStoreGroupId ?? userStoreId

            db.collection("reminders")
                .whereField("userStoreId", isEqualTo: reminderStoreId)
                .whereField("isDone", isEqualTo: false)
                .addSnapshotListener { [weak self] snapshot, error in
                    guard let self = self else { return }

                    if let error = error {
                        print("Error fetching reminders: \(error)")
                        return
                    }

                    let count = snapshot?.documents.count ?? 0
                    self.storeReminders[userStoreId] = count
                    print("LocationMonitoring: Store '\(userStore.storeName)' has \(count) incomplete reminders (using ID: \(reminderStoreId))")
                }
        }
    }

    // MARK: - Geofencing

    private func setupGeofences() {
        print("🗺️ LocationMonitoring: Setting up geofences")

        // Clear existing geofences
        removeAllGeofences()

        // iOS limits to 20 regions per app, so prioritize stores with reminders
        let storesWithCoordinates = userStores.filter { $0.latitude != nil && $0.longitude != nil }

        // Sort by reminder count (stores with more reminders get priority)
        let sortedStores = storesWithCoordinates.sorted { store1, store2 in
            let count1 = storeReminders[store1.id ?? ""] ?? 0
            let count2 = storeReminders[store2.id ?? ""] ?? 0
            return count1 > count2
        }

        // Take up to 20 stores (iOS limit)
        let storesToMonitor = Array(sortedStores.prefix(20))

        print("   Creating geofences for \(storesToMonitor.count) stores (iOS limit: 20)")

        for store in storesToMonitor {
            guard let storeId = store.id,
                  let lat = store.latitude,
                  let lon = store.longitude else {
                continue
            }

            let center = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            let region = CLCircularRegion(
                center: center,
                radius: geofenceRadius,
                identifier: "store_\(storeId)"
            )

            // Only notify when entering the region
            region.notifyOnEntry = true
            region.notifyOnExit = false

            locationManager.startMonitoring(for: region)
            activeGeofences[region.identifier] = storeId

            let reminderCount = storeReminders[storeId] ?? 0
            print("   ✓ Geofence created for '\(store.storeName)' (\(Int(geofenceRadius))m radius, \(reminderCount) reminders)")
        }

        print("   📍 Total active geofences: \(activeGeofences.count)")
    }

    private func removeAllGeofences() {
        for region in locationManager.monitoredRegions {
            locationManager.stopMonitoring(for: region)
        }
        activeGeofences.removeAll()
        print("   🗑️ Removed all existing geofences")
    }

    private func refreshGeofences() {
        // Re-setup geofences when stores or reminders change
        setupGeofences()
    }

    // MARK: - Distance Calculation & Notification

    private func checkProximityToStores(userLocation: CLLocation) {
        print("📍 LocationMonitoring: Checking proximity - User at (\(userLocation.coordinate.latitude), \(userLocation.coordinate.longitude))")
        print("   Checking against \(userStores.count) stores with \(proximityThreshold)m threshold")

        var storesChecked = 0
        var storesWithinRange = 0

        for userStore in userStores {
            // Skip stores without coordinates
            guard let lat = userStore.latitude,
                  let lon = userStore.longitude else {
                print("   ⚠️ \(userStore.storeName): SKIPPED - No coordinates")
                continue
            }

            storesChecked += 1

            let storeLocation = CLLocation(latitude: lat, longitude: lon)
            let distance = userLocation.distance(from: storeLocation)
            let distanceStr = String(format: "%.0f", distance)

            print("   📏 \(userStore.storeName): \(distanceStr)m away")

            // Check if within proximity threshold
            if distance <= proximityThreshold {
                storesWithinRange += 1
                print("      ✅ WITHIN RANGE! Checking notification conditions...")
                handleStoreProximity(userStore: userStore, distance: distance)
            }
        }

        if storesChecked == 0 {
            print("   ⚠️ No stores have coordinates to check")
        } else if storesWithinRange == 0 {
            print("   ℹ️ No stores within \(proximityThreshold)m range")
        }
    }

    private func handleStoreProximity(userStore: UserStore, distance: CLLocationDistance) {
        print("      🔔 Handling proximity for: \(userStore.storeName)")

        // Skip stores without valid IDs
        guard let userStoreId = userStore.id else {
            print("      ⚠️ Store has no ID, skipping")
            return
        }

        // Double-check notifications are enabled (safety check)
        guard userStore.notificationsEnabled else {
            print("      ⏸️ Notifications disabled for this store - skipping")
            return
        }

        // Check if we've recently notified about this store
        if let lastNotification = recentlyNotifiedStores[userStoreId] {
            let timeSinceLastNotification = Date().timeIntervalSince(lastNotification)
            let minutesAgo = Int(timeSinceLastNotification / 60)
            if timeSinceLastNotification < notificationCooldown {
                print("      ⏸️ In cooldown period (notified \(minutesAgo) minutes ago)")
                return
            } else {
                print("      ✓ Cooldown expired (last notified \(minutesAgo) minutes ago)")
            }
        } else {
            print("      ✓ No previous notifications")
        }

        // Get reminder count for this store
        let reminderCount = storeReminders[userStoreId] ?? 0
        print("      📝 Reminder count: \(reminderCount)")

        // Only notify if there are incomplete reminders
        guard reminderCount > 0 else {
            print("      ❌ No incomplete reminders - skipping notification")
            return
        }

        print("      🚀 Sending notification!")

        // Send notification
        notificationManager.scheduleStoreProximityNotification(
            storeName: userStore.storeName,
            reminderCount: reminderCount
        )

        // Update last notification time
        recentlyNotifiedStores[userStoreId] = Date()

        let distanceInMeters = Int(distance)
        print("      ✅ NOTIFICATION SENT! Store: \(userStore.storeName), Distance: \(distanceInMeters)m, Reminders: \(reminderCount)")
    }

    // MARK: - Helper Methods

    func clearNotificationHistory() {
        recentlyNotifiedStores.removeAll()
    }

    func getMonitoredStoreCount() -> Int {
        return userStores.filter { $0.latitude != nil && $0.longitude != nil }.count
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationMonitoringManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        print("\n🌍 LocationMonitoring: Location update received")
        print("   Coordinates: (\(location.coordinate.latitude), \(location.coordinate.longitude))")
        print("   Accuracy: ±\(Int(location.horizontalAccuracy))m")
        print("   Timestamp: \(Date())")

        lastLocation = location
        checkProximityToStores(userLocation: location)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ LocationMonitoring: Location manager error: \(error)")
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        let statusStr: String
        switch status {
        case .notDetermined: statusStr = "Not Determined"
        case .restricted: statusStr = "Restricted"
        case .denied: statusStr = "Denied"
        case .authorizedWhenInUse: statusStr = "When In Use"
        case .authorizedAlways: statusStr = "Always"
        @unknown default: statusStr = "Unknown"
        }

        print("🔐 LocationMonitoring: Authorization changed to: \(statusStr)")

        // Start monitoring with either "When In Use" or "Always" permission
        if (status == .authorizedAlways || status == .authorizedWhenInUse), let userId = currentUserId, !isMonitoring {
            print("   ✅ Starting monitoring automatically")
            startMonitoring(userId: userId)
        } else if (status == .authorizedAlways || status == .authorizedWhenInUse) && isMonitoring {
            print("   ✅ Resuming location updates")
            // Resume monitoring if already configured
            locationManager.startUpdatingLocation()

            // Configure based on permission level
            if status == .authorizedWhenInUse {
                // Re-enable significant location changes for "When In Use"
                locationManager.startMonitoringSignificantLocationChanges()
                print("   📱 Re-enabled significant location changes")
            } else if status == .authorizedAlways {
                // Enable background updates for "Always" permission
                locationManager.allowsBackgroundLocationUpdates = true
                print("   📱 Enabled background location updates")
            }
        } else if status == .denied || status == .restricted {
            print("   ❌ Location permission denied or restricted")
        }
    }

    // MARK: - Region Monitoring Delegates

    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        print("\n🎯 LocationMonitoring: ENTERED GEOFENCE!")
        print("   Region: \(region.identifier)")

        guard let storeId = activeGeofences[region.identifier] else {
            print("   ⚠️ Unknown region, ignoring")
            return
        }

        // Find the store
        guard let store = userStores.first(where: { $0.id == storeId }) else {
            print("   ⚠️ Store not found: \(storeId)")
            return
        }

        print("   Store: \(store.storeName)")

        // Get current location for precise distance calculation
        if let currentLocation = lastLocation ?? manager.location {
            // Use the existing proximity check logic
            let storeLocation = CLLocation(
                latitude: store.latitude ?? 0,
                longitude: store.longitude ?? 0
            )
            let distance = currentLocation.distance(from: storeLocation)

            print("   Distance: \(Int(distance))m")

            // Handle the store proximity
            handleStoreProximity(userStore: store, distance: distance)
        } else {
            print("   ⚠️ No current location available")

            // Request a location update to get current position
            manager.requestLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        print("\n🚪 LocationMonitoring: Exited geofence: \(region.identifier)")
        // We don't need to do anything on exit for now
    }

    func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        if let region = region {
            print("❌ LocationMonitoring: Geofence monitoring failed for \(region.identifier): \(error)")
        } else {
            print("❌ LocationMonitoring: Geofence monitoring failed: \(error)")
        }
    }

    func locationManager(_ manager: CLLocationManager, didStartMonitoringFor region: CLRegion) {
        print("✅ LocationMonitoring: Started monitoring geofence: \(region.identifier)")
    }
}
