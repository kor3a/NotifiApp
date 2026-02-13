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

    // Distance threshold in meters for proximity notification
    private let proximityThreshold: CLLocationDistance = 150

    // Search radius for finding nearby stores (5km)
    private let searchRadius: CLLocationDistance = 5000

    // Track recently notified stores to avoid spam (store name -> last notification time)
    private var recentlyNotifiedStores: [String: Date] = [:]
    private let notificationCooldown: TimeInterval = 3600 // 1 hour cooldown

    // Debounce for location searches
    private var lastSearchTime: Date?
    private let searchDebounceInterval: TimeInterval = 30 // Don't search more than once per 30 seconds

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
            #if DEBUG
            print("🔄 LocationMonitoring: Restored user ID from UserDefaults: \(savedUserId)")
            #endif

            // Auto-start monitoring if we have permission
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
        locationManager.distanceFilter = 100 // Update every 100 meters
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

        // Accept both "When In Use" and "Always" permissions
        guard permission == .authorizedAlways || permission == .authorizedWhenInUse else {
            #if DEBUG
            print("⚠️ LocationMonitoring: Cannot start monitoring without location permission")
            print("User ID saved - will auto-start when permission is granted")
            #endif
            return
        }

        if permission == .authorizedWhenInUse {
            #if DEBUG
            print("⚠️ LocationMonitoring: Running with 'When In Use' permission")
            print("   App will monitor location while in use and use significant location changes in background")
            #endif
            locationManager.startMonitoringSignificantLocationChanges()
        } else if permission == .authorizedAlways {
            #if DEBUG
            print("✅ LocationMonitoring: Running with 'Always' permission")
            print("   App will monitor location continuously, even in background")
            #endif
            locationManager.allowsBackgroundLocationUpdates = true
        }

        isMonitoring = true
        loadUserStores(userId: userId)
        locationManager.startUpdatingLocation()
        #if DEBUG
        print("✅ LocationMonitoring: Started location monitoring successfully")
        print("📱 LocationMonitoring: Desired accuracy: \(locationManager.desiredAccuracy)")
        print("📱 LocationMonitoring: Distance filter: \(locationManager.distanceFilter)m")
        #endif
    }

    func stopMonitoring() {
        isMonitoring = false
        locationManager.stopUpdatingLocation()
        locationManager.stopMonitoringSignificantLocationChanges()
        #if DEBUG
        print("Stopped location monitoring")
        #endif
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

                // Clear old reminder counts before loading new stores
                self.storeReminders.removeAll()

                self.userStores = documents.compactMap { doc -> UserStore? in
                    do {
                        var userStore = try doc.data(as: UserStore.self)
                        userStore.id = doc.documentID

                        // Only include stores with notifications enabled
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

                // Load reminder counts for each store
                self.loadReminderCounts()
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

            // Determine which ID to use for fetching reminders
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

    // MARK: - Nearby Store Search

    /// Search for nearby stores matching user's saved store names
    private func searchForNearbyMatchingStores(userLocation: CLLocation) {
        // Debounce: don't search too frequently
        if let lastSearch = lastSearchTime,
           Date().timeIntervalSince(lastSearch) < searchDebounceInterval {
            #if DEBUG
            print("📍 LocationMonitoring: Skipping search (debounce)")
            #endif
            return
        }
        lastSearchTime = Date()

        #if DEBUG
        print("📍 LocationMonitoring: Searching for nearby stores at (\(userLocation.coordinate.latitude), \(userLocation.coordinate.longitude))")
        #endif

        // Get unique store names that user is tracking
        let storeNames = Set(userStores.map { $0.storeName })

        guard !storeNames.isEmpty else {
            #if DEBUG
            print("   ⚠️ No stores to search for")
            #endif
            return
        }

        #if DEBUG
        print("   🔍 Looking for: \(storeNames.joined(separator: ", "))")
        #endif

        // Search for each store name
        for storeName in storeNames {
            searchForStore(name: storeName, near: userLocation)
        }
    }

    /// Search MapKit for a specific store near user's location
    private func searchForStore(name: String, near userLocation: CLLocation) {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = name
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
                print("   ❌ Search error for '\(name)': \(error.localizedDescription)")
                #endif
                return
            }

            guard let response = response else {
                #if DEBUG
                print("   ℹ️ No results for '\(name)'")
                #endif
                return
            }

            // Check each result for proximity
            for mapItem in response.mapItems {
                guard let itemName = mapItem.name,
                      let location = mapItem.placemark.location else {
                    continue
                }

                // Check if this result matches our store name (normalized comparison)
                let normalizedSearchName = Store.normalizedId(from: name)
                let normalizedResultName = Store.normalizedId(from: itemName)

                guard normalizedSearchName == normalizedResultName else {
                    continue
                }

                let distance = userLocation.distance(from: location)

                if distance <= self.proximityThreshold {
                    #if DEBUG
                    print("   ✅ Found '\(itemName)' within \(Int(distance))m!")
                    #endif
                    self.handleNearbyStoreFound(storeName: name, distance: distance)
                    return // Only notify once per store name
                }
            }
        }
    }

    /// Handle finding a nearby store that matches user's saved stores
    private func handleNearbyStoreFound(storeName: String, distance: CLLocationDistance) {
        #if DEBUG
        print("      🔔 Handling proximity for: \(storeName)")
        #endif

        // Find the user store for this name
        guard let userStore = userStores.first(where: { $0.storeName == storeName }),
              let userStoreId = userStore.id else {
            #if DEBUG
            print("      ⚠️ Could not find user store for '\(storeName)'")
            #endif
            return
        }

        // Use normalized store name for cooldown tracking (so all locations share cooldown)
        let normalizedName = Store.normalizedId(from: storeName)

        // Check cooldown
        if let lastNotification = recentlyNotifiedStores[normalizedName] {
            let timeSinceLastNotification = Date().timeIntervalSince(lastNotification)
            let minutesAgo = Int(timeSinceLastNotification / 60)
            if timeSinceLastNotification < notificationCooldown {
                #if DEBUG
                print("      ⏸️ In cooldown period (notified \(minutesAgo) minutes ago)")
                #endif
                return
            } else {
                #if DEBUG
                print("      ✓ Cooldown expired (last notified \(minutesAgo) minutes ago)")
                #endif
            }
        } else {
            #if DEBUG
            print("      ✓ No previous notifications")
            #endif
        }

        // Get reminder count
        let reminderCount = storeReminders[userStoreId] ?? 0
        #if DEBUG
        print("      📝 Reminder count: \(reminderCount)")
        #endif

        // Only notify if there are incomplete reminders
        guard reminderCount > 0 else {
            #if DEBUG
            print("      ❌ No incomplete reminders - skipping notification")
            #endif
            return
        }

        #if DEBUG
        print("      🚀 Sending notification!")
        #endif

        // Send notification
        notificationManager.scheduleStoreProximityNotification(
            storeName: storeName,
            reminderCount: reminderCount
        )

        // Update cooldown using normalized name
        recentlyNotifiedStores[normalizedName] = Date()

        #if DEBUG
        let distanceInMeters = Int(distance)
        print("      ✅ NOTIFICATION SENT! Store: \(storeName), Distance: \(distanceInMeters)m, Reminders: \(reminderCount)")
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
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        #if DEBUG
        print("\n🌍 LocationMonitoring: Location update received")
        print("   Coordinates: (\(location.coordinate.latitude), \(location.coordinate.longitude))")
        print("   Accuracy: ±\(Int(location.horizontalAccuracy))m")
        print("   Timestamp: \(Date())")
        #endif

        lastLocation = location

        // Search for nearby stores matching user's saved store names
        searchForNearbyMatchingStores(userLocation: location)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        #if DEBUG
        print("❌ LocationMonitoring: Location manager error: \(error)")
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

        // Start monitoring with either "When In Use" or "Always" permission
        if (status == .authorizedAlways || status == .authorizedWhenInUse), let userId = currentUserId, !isMonitoring {
            #if DEBUG
            print("   ✅ Starting monitoring automatically")
            #endif
            startMonitoring(userId: userId)
        } else if (status == .authorizedAlways || status == .authorizedWhenInUse) && isMonitoring {
            #if DEBUG
            print("   ✅ Resuming location updates")
            #endif
            locationManager.startUpdatingLocation()

            if status == .authorizedWhenInUse {
                locationManager.startMonitoringSignificantLocationChanges()
                #if DEBUG
                print("   📱 Re-enabled significant location changes")
                #endif
            } else if status == .authorizedAlways {
                locationManager.allowsBackgroundLocationUpdates = true
                #if DEBUG
                print("   📱 Enabled background location updates")
                #endif
            }
        } else if status == .denied || status == .restricted {
            #if DEBUG
            print("   ❌ Location permission denied or restricted")
            #endif
        }
    }
}
