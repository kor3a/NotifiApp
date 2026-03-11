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
import MapKit

class LocationMonitoringManager: NSObject, ObservableObject {
    static let shared = LocationMonitoringManager()

    private let locationManager = CLLocationManager()
    private let db = Firestore.firestore()
    private let notificationManager = NotificationManager.shared

    // Distance threshold in meters for proximity notification (geofence radius)
    private let proximityThreshold: CLLocationDistance = 150

    // Search radius for finding nearby stores to geofence (5km)
    private let searchRadius: CLLocationDistance = 5000

    // Track recently notified stores to avoid spam (normalized store name -> last notification time)
    private var recentlyNotifiedStores: [String: Date] = [:]
    private let notificationCooldown: TimeInterval = 3600 // 1 hour cooldown

    // Maps geofence region identifiers to user store IDs
    private var regionToUserStoreId: [String: String] = [:]

    // Debounce geofence refresh so we don't hammer MapKit on every significant change
    private var lastGeofenceRefreshTime: Date?
    private let geofenceRefreshDebounce: TimeInterval = 300 // Refresh at most every 5 minutes

    @Published var isMonitoring = false
    @Published var lastLocation: CLLocation?

    private var userStores: [UserStore] = []
    private var storeReminders: [String: Int] = [:] // userStoreId -> incomplete reminder count
    private var currentUserId: String? {
        didSet {
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
            #if DEBUG
            print("🔄 LocationMonitoring: Restored user ID from UserDefaults: \(savedUserId)")
            #endif

            let status = locationManager.authorizationStatus
            if status == .authorizedAlways || status == .authorizedWhenInUse {
                #if DEBUG
                print("   ✅ Auto-starting monitoring (app may have been launched in background)")
                #endif
                startMonitoring(userId: savedUserId)
            }
        }
    }

    // MARK: - Setup

    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
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
            #if DEBUG
            print("Already have always authorization")
            #endif
        case .restricted, .denied:
            #if DEBUG
            print("Location permission denied or restricted")
            #endif
        @unknown default:
            #if DEBUG
            print("Unknown authorization status")
            #endif
        }
    }

    func checkLocationPermission() -> CLAuthorizationStatus {
        return locationManager.authorizationStatus
    }

    // MARK: - Monitoring Control

    func setUserId(_ userId: String) {
        currentUserId = userId
        #if DEBUG
        print("LocationMonitoring: Set user ID to \(userId)")
        #endif
    }

    func startMonitoring(userId: String) {
        currentUserId = userId

        #if DEBUG
        print("🔵 LocationMonitoring: startMonitoring called for userId: \(userId)")
        #endif

        let permission = checkLocationPermission()

        guard permission == .authorizedAlways || permission == .authorizedWhenInUse else {
            #if DEBUG
            print("⚠️ LocationMonitoring: Cannot start monitoring without location permission")
            print("User ID saved - will auto-start when permission is granted")
            #endif
            return
        }

        isMonitoring = true

        // Use significant-change location service to detect major movements and
        // refresh geofences. This does not require the "location" UIBackgroundMode.
        locationManager.startMonitoringSignificantLocationChanges()

        // Request a one-time location fix to seed the initial geofence registration.
        locationManager.requestLocation()

        loadUserStores(userId: userId)

        #if DEBUG
        print("✅ LocationMonitoring: Started monitoring (significant-change + geofencing)")
        #endif
    }

    func stopMonitoring() {
        isMonitoring = false
        locationManager.stopMonitoringSignificantLocationChanges()
        stopAllGeofences()
        #if DEBUG
        print("Stopped location monitoring")
        #endif
    }

    // MARK: - Geofence Management

    private func stopAllGeofences() {
        for region in locationManager.monitoredRegions {
            locationManager.stopMonitoring(for: region)
        }
        regionToUserStoreId.removeAll()
        #if DEBUG
        print("🗺️ LocationMonitoring: Removed all geofences")
        #endif
    }

    /// Re-evaluate geofences around the given location. Called on initial location
    /// fix and after significant location changes.
    private func refreshGeofences(for location: CLLocation) {
        // Debounce: avoid hammering MapKit on rapid successive calls
        if let last = lastGeofenceRefreshTime,
           Date().timeIntervalSince(last) < geofenceRefreshDebounce {
            #if DEBUG
            print("🗺️ LocationMonitoring: Skipping geofence refresh (debounce)")
            #endif
            return
        }
        lastGeofenceRefreshTime = Date()

        let storeNames = Set(userStores.map { $0.storeName })
        guard !storeNames.isEmpty else {
            #if DEBUG
            print("⚠️ LocationMonitoring: No stores to geofence")
            #endif
            return
        }

        #if DEBUG
        print("🗺️ LocationMonitoring: Refreshing geofences for \(storeNames.count) store name(s)")
        #endif

        // Clear existing app-registered geofences before registering fresh ones
        stopAllGeofences()

        for storeName in storeNames {
            searchAndRegisterGeofences(for: storeName, near: location)
        }
    }

    /// Search MapKit for a store by name near the user and register a geofence
    /// for each matching result that falls within the search radius.
    private func searchAndRegisterGeofences(for storeName: String, near userLocation: CLLocation) {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = storeName
        request.region = MKCoordinateRegion(
            center: userLocation.coordinate,
            latitudinalMeters: searchRadius * 2,
            longitudinalMeters: searchRadius * 2
        )

        let search = MKLocalSearch(request: request)
        search.start { [weak self] response, error in
            guard let self = self else { return }

            if let error = error {
                #if DEBUG
                print("   ❌ Geofence search error for '\(storeName)': \(error.localizedDescription)")
                #endif
                return
            }

            guard let response = response else { return }

            let normalizedSearchName = Store.normalizedId(from: storeName)

            for mapItem in response.mapItems {
                guard let itemName = mapItem.name,
                      let itemLocation = mapItem.placemark.location else { continue }

                // Only consider results whose name matches the saved store name
                let normalizedResultName = Store.normalizedId(from: itemName)
                guard normalizedSearchName == normalizedResultName else { continue }

                // Only geofence stores within the search radius
                let distance = userLocation.distance(from: itemLocation)
                guard distance <= self.searchRadius else { continue }

                // Find the user store entry so we can map the region identifier to it
                guard let userStore = self.userStores.first(where: {
                    Store.normalizedId(from: $0.storeName) == normalizedSearchName
                }), let userStoreId = userStore.id else { continue }

                // Cap total monitored regions at iOS limit (20)
                guard self.locationManager.monitoredRegions.count < 20 else {
                    #if DEBUG
                    print("⚠️ LocationMonitoring: Reached 20-region iOS limit, skipping remaining stores")
                    #endif
                    return
                }

                // Use a UUID-keyed identifier to avoid parsing store names back out of strings
                let identifier = UUID().uuidString
                let region = CLCircularRegion(
                    center: mapItem.placemark.coordinate,
                    radius: self.proximityThreshold,
                    identifier: identifier
                )
                region.notifyOnEntry = true
                region.notifyOnExit = false

                self.regionToUserStoreId[identifier] = userStoreId
                self.locationManager.startMonitoring(for: region)

                #if DEBUG
                print("   📍 Geofenced '\(storeName)' at \(Int(distance))m away (id: \(identifier.prefix(8))…)")
                #endif
            }
        }
    }

    // MARK: - Data Loading

    private func loadUserStores(userId: String) {
        #if DEBUG
        print("🔄 LocationMonitoring: Loading user stores for userId: \(userId)")
        #endif

        db.collection("user_stores")
            .whereField("userId", isEqualTo: userId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }

                if let error = error {
                    #if DEBUG
                    print("❌ LocationMonitoring: Error fetching user stores: \(error)")
                    #endif
                    return
                }

                guard let documents = snapshot?.documents else {
                    #if DEBUG
                    print("⚠️ LocationMonitoring: No user stores found")
                    #endif
                    return
                }

                self.storeReminders.removeAll()

                self.userStores = documents.compactMap { doc -> UserStore? in
                    do {
                        var userStore = try doc.data(as: UserStore.self)
                        userStore.id = doc.documentID

                        guard userStore.notificationsEnabled else {
                            #if DEBUG
                            print("   ⏸️ Skipping store '\(userStore.storeName)' - notifications disabled")
                            #endif
                            return nil
                        }

                        #if DEBUG
                        print("   ✓ Loaded store '\(userStore.storeName)' - notifications enabled")
                        #endif
                        return userStore
                    } catch {
                        #if DEBUG
                        print("❌ LocationMonitoring: Failed to decode store \(doc.documentID): \(error)")
                        #endif
                        return nil
                    }
                }

                #if DEBUG
                print("📦 LocationMonitoring: Loaded \(self.userStores.count) stores for monitoring")
                #endif

                self.loadReminderCounts()

                // Refresh geofences whenever the store list changes
                if let location = self.lastLocation {
                    self.lastGeofenceRefreshTime = nil // Force immediate refresh
                    self.refreshGeofences(for: location)
                }
            }
    }

    private func loadReminderCounts() {
        for userStore in userStores {
            guard let userStoreId = userStore.id else {
                #if DEBUG
                print("⚠️ LocationMonitoring: Store '\(userStore.storeName)' has no ID, skipping")
                #endif
                continue
            }

            let reminderStoreId = userStore.sourceUserStoreId ?? userStore.sharedStoreGroupId ?? userStoreId

            db.collection("reminders")
                .whereField("userStoreId", isEqualTo: reminderStoreId)
                .whereField("isDone", isEqualTo: false)
                .addSnapshotListener { [weak self] snapshot, error in
                    guard let self = self else { return }

                    if let error = error {
                        #if DEBUG
                        print("Error fetching reminders: \(error)")
                        #endif
                        return
                    }

                    let count = snapshot?.documents.count ?? 0
                    self.storeReminders[userStoreId] = count
                    #if DEBUG
                    print("LocationMonitoring: Store '\(userStore.storeName)' has \(count) incomplete reminders")
                    #endif
                }
        }
    }

    // MARK: - Proximity Handling

    private func handleStoreProximity(userStoreId: String) {
        guard let userStore = userStores.first(where: { $0.id == userStoreId }) else {
            #if DEBUG
            print("⚠️ LocationMonitoring: No user store found for id \(userStoreId)")
            #endif
            return
        }

        let normalizedName = Store.normalizedId(from: userStore.storeName)

        // Cooldown check
        if let lastNotification = recentlyNotifiedStores[normalizedName] {
            let timeSinceLastNotification = Date().timeIntervalSince(lastNotification)
            guard timeSinceLastNotification >= notificationCooldown else {
                #if DEBUG
                let minutesAgo = Int(timeSinceLastNotification / 60)
                print("⏸️ LocationMonitoring: In cooldown for '\(userStore.storeName)' (notified \(minutesAgo) min ago)")
                #endif
                return
            }
        }

        let reminderCount = storeReminders[userStoreId] ?? 0
        guard reminderCount > 0 else {
            #if DEBUG
            print("❌ LocationMonitoring: No incomplete reminders for '\(userStore.storeName)' - skipping")
            #endif
            return
        }

        notificationManager.scheduleStoreProximityNotification(
            storeName: userStore.storeName,
            reminderCount: reminderCount
        )
        recentlyNotifiedStores[normalizedName] = Date()

        #if DEBUG
        print("✅ LocationMonitoring: Notification sent for '\(userStore.storeName)' (\(reminderCount) reminders)")
        #endif
    }

    // MARK: - Helper Methods

    func clearNotificationHistory() {
        recentlyNotifiedStores.removeAll()
    }

    func getMonitoredStoreCount() -> Int {
        return userStores.count
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationMonitoringManager: CLLocationManagerDelegate {

    /// Called for the one-time `requestLocation()` fix and for significant-change updates.
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        #if DEBUG
        print("\n🌍 LocationMonitoring: Location update received")
        print("   Coordinates: (\(location.coordinate.latitude), \(location.coordinate.longitude))")
        print("   Accuracy: ±\(Int(location.horizontalAccuracy))m")
        #endif

        lastLocation = location
        refreshGeofences(for: location)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        #if DEBUG
        print("❌ LocationMonitoring: Location manager error: \(error)")
        #endif
    }

    /// Called by iOS when the user enters a monitored geofence region.
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        guard let userStoreId = regionToUserStoreId[region.identifier] else {
            #if DEBUG
            print("⚠️ LocationMonitoring: Entered unknown region \(region.identifier.prefix(8))…")
            #endif
            return
        }

        #if DEBUG
        print("📍 LocationMonitoring: Entered geofence for store id \(userStoreId)")
        #endif

        handleStoreProximity(userStoreId: userStoreId)
    }

    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        // Exit notifications are disabled; no action needed.
    }

    func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        #if DEBUG
        let id = region?.identifier.prefix(8) ?? "unknown"
        print("❌ LocationMonitoring: Geofence monitoring failed for region \(id)…: \(error)")
        #endif
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        #if DEBUG
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
        #endif

        if (status == .authorizedAlways || status == .authorizedWhenInUse),
           let userId = currentUserId, !isMonitoring {
            #if DEBUG
            print("   ✅ Starting monitoring automatically")
            #endif
            startMonitoring(userId: userId)
        } else if status == .denied || status == .restricted {
            stopMonitoring()
        }
    }
}
