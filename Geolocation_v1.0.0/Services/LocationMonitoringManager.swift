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

    // Track recently notified stores to avoid spam (store ID -> last notification time)
    private var recentlyNotifiedStores: [String: Date] = [:]
    private let notificationCooldown: TimeInterval = 3600 // 1 hour cooldown

    @Published var isMonitoring = false
    @Published var lastLocation: CLLocation?

    private var userStores: [UserStore] = []
    private var storeReminders: [String: Int] = [:] // userStoreId -> incomplete reminder count
    private var currentUserId: String?

    private override init() {
        super.init()
        setupLocationManager()
    }

    // MARK: - Setup

    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager.distanceFilter = 100 // Update every 100 meters
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false

        // Also start monitoring significant location changes for better background updates
        // This works with "When In Use" permission when app is in background
        locationManager.startMonitoringSignificantLocationChanges()
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
        }

        isMonitoring = true
        loadUserStores(userId: userId)
        locationManager.startUpdatingLocation()
        print("✅ LocationMonitoring: Started location monitoring successfully")
        print("📱 LocationMonitoring: Desired accuracy: \(locationManager.desiredAccuracy)")
        print("📱 LocationMonitoring: Distance filter: \(locationManager.distanceFilter)m")
        print("📱 LocationMonitoring: Background updates: \(locationManager.allowsBackgroundLocationUpdates)")
        print("📱 LocationMonitoring: Significant location changes: enabled")
    }

    func stopMonitoring() {
        isMonitoring = false
        locationManager.stopUpdatingLocation()
        print("Stopped location monitoring")
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

                print("📦 LocationMonitoring: Loaded \(self.userStores.count) stores for monitoring")

                // Log details about each store
                for store in self.userStores {
                    let hasCoords = store.latitude != nil && store.longitude != nil
                    let coordsStr = hasCoords ? "✓ (\(store.latitude!), \(store.longitude!))" : "✗ NO COORDINATES"
                    print("   - \(store.storeName): \(coordsStr)")
                }

                // Load reminder counts for each store
                self.loadReminderCounts()
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
                    print("LocationMonitoring: Store '\(userStore.storeName)' has \(count) incomplete reminders (using ID: \(reminderStoreId))")
                }
        }
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

        // Check if we've recently notified about this store
        if let lastNotification = recentlyNotifiedStores[userStore.id] {
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
        let reminderCount = storeReminders[userStore.id] ?? 0
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
        recentlyNotifiedStores[userStore.id] = Date()

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
        } else if status == .denied || status == .restricted {
            print("   ❌ Location permission denied or restricted")
        }
    }
}
