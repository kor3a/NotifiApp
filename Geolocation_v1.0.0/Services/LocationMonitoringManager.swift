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

    // Geofence radius in meters - iOS allows up to 100m minimum
    private let geofenceRadius: CLLocationDistance = 100

    // Track recently notified stores to avoid spam (store ID -> last notification time)
    private var recentlyNotifiedStores: [String: Date] = [:]
    private let notificationCooldown: TimeInterval = 3600 // 1 hour cooldown

    @Published var isMonitoring = false
    @Published var lastLocation: CLLocation?

    private var userStores: [UserStore] = []
    private var storeReminders: [String: Int] = [:] // userStoreId -> incomplete reminder count
    private var currentUserId: String?
    private var monitoredRegions: Set<String> = [] // Track which stores we're monitoring

    private override init() {
        super.init()
        setupLocationManager()
    }

    // MARK: - Setup

    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters

        // For geofencing, we don't need continuous location updates
        // Geofencing works in the background with "When In Use" permission

        print("📍 LocationMonitoring: Location manager configured for geofencing")
        print("   Max monitored regions: \(locationManager.maximumRegionMonitoringDistance)")
    }

    // MARK: - Permission Management

    func requestLocationPermission() {
        let status = locationManager.authorizationStatus

        switch status {
        case .notDetermined:
            // Request "When In Use" permission - this is enough for geofencing
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse:
            print("✅ Have 'When In Use' permission - geofencing will work!")
        case .authorizedAlways:
            print("✅ Have 'Always' permission - geofencing will work!")
        case .restricted, .denied:
            print("❌ Location permission denied or restricted")
        @unknown default:
            print("⚠️ Unknown authorization status")
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
            print("✅ LocationMonitoring: Running with 'When In Use' permission")
            print("   Geofencing will work in background and when phone is locked!")
        }

        isMonitoring = true
        loadUserStores(userId: userId)
        print("✅ LocationMonitoring: Started geofence monitoring successfully")
    }

    func stopMonitoring() {
        isMonitoring = false

        // Stop monitoring all regions
        for region in locationManager.monitoredRegions {
            locationManager.stopMonitoring(for: region)
        }

        monitoredRegions.removeAll()
        print("Stopped geofence monitoring - removed all regions")
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

                self.userStores = documents.compactMap { doc -> UserStore? in
                    try? doc.data(as: UserStore.self)
                }

                print("📦 LocationMonitoring: Loaded \(self.userStores.count) stores")

                // Log details about each store
                for store in self.userStores {
                    let hasCoords = store.latitude != nil && store.longitude != nil
                    let coordsStr = hasCoords ? "✓ (\(store.latitude!), \(store.longitude!))" : "✗ NO COORDINATES"
                    print("   - \(store.storeName): \(coordsStr)")
                }

                // Load reminder counts and set up geofences
                self.loadReminderCounts()
                self.setupGeofences()
            }
    }

    private func loadReminderCounts() {
        for userStore in userStores {
            // Determine which ID to use for fetching reminders
            // Priority: sourceUserStoreId (view only) > sharedStoreGroupId (can edit) > userStore.id (owner)
            let reminderStoreId = userStore.sourceUserStoreId ?? userStore.sharedStoreGroupId ?? userStore.id

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
                    self.storeReminders[userStore.id] = count
                    print("LocationMonitoring: Store '\(userStore.storeName)' has \(count) incomplete reminders")
                }
        }
    }

    // MARK: - Geofencing

    private func setupGeofences() {
        print("\n🗺️ LocationMonitoring: Setting up geofences...")

        // First, stop monitoring any existing regions that are no longer in our store list
        let currentStoreIds = Set(userStores.compactMap { $0.id })
        for region in locationManager.monitoredRegions {
            if let circularRegion = region as? CLCircularRegion {
                let regionStoreId = circularRegion.identifier
                if !currentStoreIds.contains(regionStoreId) {
                    locationManager.stopMonitoring(for: region)
                    monitoredRegions.remove(regionStoreId)
                    print("   ❌ Removed geofence for old store: \(regionStoreId)")
                }
            }
        }

        var geofencesCreated = 0
        var geofencesSkipped = 0

        for userStore in userStores {
            // Skip stores without coordinates
            guard let lat = userStore.latitude,
                  let lon = userStore.longitude else {
                print("   ⚠️ \(userStore.storeName): SKIPPED - No coordinates")
                geofencesSkipped += 1
                continue
            }

            // Check if we're already monitoring this store
            if monitoredRegions.contains(userStore.id) {
                print("   ℹ️ \(userStore.storeName): Already monitoring")
                continue
            }

            // Create circular region around store
            let center = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            let region = CLCircularRegion(
                center: center,
                radius: geofenceRadius,
                identifier: userStore.id // Use store ID as identifier
            )

            // Configure region
            region.notifyOnEntry = true
            region.notifyOnExit = false // We only care about entry

            // Start monitoring this region
            locationManager.startMonitoring(for: region)
            monitoredRegions.insert(userStore.id)
            geofencesCreated += 1

            print("   ✅ \(userStore.storeName): Geofence created (radius: \(Int(geofenceRadius))m)")
        }

        print("\n📊 Geofence Summary:")
        print("   Created: \(geofencesCreated)")
        print("   Skipped: \(geofencesSkipped)")
        print("   Total monitoring: \(monitoredRegions.count)")
        print("   iOS limit: 20 regions max\n")

        if monitoredRegions.count > 20 {
            print("⚠️ WARNING: Monitoring \(monitoredRegions.count) regions, but iOS only allows 20!")
            print("   Consider monitoring only your closest or most frequently visited stores.")
        }
    }

    // MARK: - Notification Handling

    private func handleStoreProximity(storeId: String) {
        print("\n🔔 LocationMonitoring: User entered geofence for store: \(storeId)")

        // Find the store
        guard let userStore = userStores.first(where: { $0.id == storeId }) else {
            print("   ❌ Store not found in local cache")
            return
        }

        print("   📍 Store: \(userStore.storeName)")

        // Check if we've recently notified about this store
        if let lastNotification = recentlyNotifiedStores[userStore.id] {
            let timeSinceLastNotification = Date().timeIntervalSince(lastNotification)
            let minutesAgo = Int(timeSinceLastNotification / 60)
            if timeSinceLastNotification < notificationCooldown {
                print("   ⏸️ In cooldown period (notified \(minutesAgo) minutes ago)")
                return
            } else {
                print("   ✓ Cooldown expired (last notified \(minutesAgo) minutes ago)")
            }
        } else {
            print("   ✓ No previous notifications")
        }

        // Get reminder count for this store
        let reminderCount = storeReminders[userStore.id] ?? 0
        print("   📝 Reminder count: \(reminderCount)")

        // Only notify if there are incomplete reminders
        guard reminderCount > 0 else {
            print("   ❌ No incomplete reminders - skipping notification")
            return
        }

        print("   🚀 Sending notification!")

        // Send notification
        notificationManager.scheduleStoreProximityNotification(
            storeName: userStore.storeName,
            reminderCount: reminderCount
        )

        // Update last notification time
        recentlyNotifiedStores[userStore.id] = Date()

        print("   ✅ NOTIFICATION SENT! Store: \(userStore.storeName), Reminders: \(reminderCount)\n")
    }

    // MARK: - Helper Methods

    func clearNotificationHistory() {
        recentlyNotifiedStores.removeAll()
        print("🗑️ Cleared notification cooldown history")
    }

    func getMonitoredStoreCount() -> Int {
        return monitoredRegions.count
    }

    func refreshGeofences() {
        print("🔄 Manually refreshing geofences...")
        setupGeofences()
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationMonitoringManager: CLLocationManagerDelegate {
    // This is called when the user enters a geofenced region
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        guard let circularRegion = region as? CLCircularRegion else { return }

        print("\n📍 GEOFENCE ENTERED!")
        print("   Region ID: \(circularRegion.identifier)")
        print("   Center: (\(circularRegion.center.latitude), \(circularRegion.center.longitude))")
        print("   Radius: \(circularRegion.radius)m")

        // The region identifier is the store ID
        handleStoreProximity(storeId: circularRegion.identifier)
    }

    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        guard let circularRegion = region as? CLCircularRegion else { return }
        print("👋 Exited geofence: \(circularRegion.identifier)")
    }

    func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        if let region = region {
            print("❌ Geofence monitoring failed for region \(region.identifier): \(error)")
        } else {
            print("❌ Geofence monitoring failed: \(error)")
        }
    }

    func locationManager(_ manager: CLLocationManager, didStartMonitoringFor region: CLRegion) {
        print("✅ Started monitoring geofence: \(region.identifier)")

        // Request the initial state - are we already inside this region?
        manager.requestState(for: region)
    }

    func locationManager(_ manager: CLLocationManager, didDetermineState state: CLRegionState, for region: CLRegion) {
        let stateStr = state == .inside ? "INSIDE" : (state == .outside ? "outside" : "unknown")
        print("📍 Region \(region.identifier) state: \(stateStr)")

        // If we're already inside the region when we start monitoring, trigger the notification
        if state == .inside {
            print("   🎯 Already inside region - triggering notification")
            if let circularRegion = region as? CLCircularRegion {
                handleStoreProximity(storeId: circularRegion.identifier)
            }
        }
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
        case .authorizedWhenInUse: statusStr = "When In Use ✅"
        case .authorizedAlways: statusStr = "Always ✅"
        @unknown default: statusStr = "Unknown"
        }

        print("🔐 LocationMonitoring: Authorization changed to: \(statusStr)")

        // Start monitoring with either "When In Use" or "Always" permission
        if (status == .authorizedAlways || status == .authorizedWhenInUse), let userId = currentUserId, !isMonitoring {
            print("   ✅ Starting geofence monitoring automatically")
            startMonitoring(userId: userId)
        } else if status == .denied || status == .restricted {
            print("   ❌ Location permission denied or restricted")
        }
    }
}
