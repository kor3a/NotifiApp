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
    private let proximityThreshold: CLLocationDistance = 1000

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

        guard checkLocationPermission() == .authorizedAlways else {
            print("Cannot start monitoring without 'Always' location permission")
            print("User ID saved - will auto-start when permission is granted")
            return
        }

        isMonitoring = true
        loadUserStores(userId: userId)
        locationManager.startUpdatingLocation()
        print("Started location monitoring")
    }

    func stopMonitoring() {
        isMonitoring = false
        locationManager.stopUpdatingLocation()
        print("Stopped location monitoring")
    }

    // MARK: - Data Loading

    private func loadUserStores(userId: String) {
        db.collection("user_stores")
            .whereField("userId", isEqualTo: userId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }

                if let error = error {
                    print("Error fetching user stores: \(error)")
                    return
                }

                guard let documents = snapshot?.documents else {
                    print("No user stores found")
                    return
                }

                self.userStores = documents.compactMap { doc -> UserStore? in
                    try? doc.data(as: UserStore.self)
                }

                print("Loaded \(self.userStores.count) stores for monitoring")

                // Load reminder counts for each store
                self.loadReminderCounts()
            }
    }

    private func loadReminderCounts() {
        for userStore in userStores {
            db.collection("reminders")
                .whereField("userStoreId", isEqualTo: userStore.id)
                .whereField("isDone", isEqualTo: false)
                .addSnapshotListener { [weak self] snapshot, error in
                    guard let self = self else { return }

                    if let error = error {
                        print("Error fetching reminders: \(error)")
                        return
                    }

                    let count = snapshot?.documents.count ?? 0
                    self.storeReminders[userStore.id] = count
                }
        }
    }

    // MARK: - Distance Calculation & Notification

    private func checkProximityToStores(userLocation: CLLocation) {
        for userStore in userStores {
            // Skip stores without coordinates
            guard let lat = userStore.latitude,
                  let lon = userStore.longitude else {
                continue
            }

            let storeLocation = CLLocation(latitude: lat, longitude: lon)
            let distance = userLocation.distance(from: storeLocation)

            // Check if within proximity threshold
            if distance <= proximityThreshold {
                handleStoreProximity(userStore: userStore, distance: distance)
            }
        }
    }

    private func handleStoreProximity(userStore: UserStore, distance: CLLocationDistance) {
        // Check if we've recently notified about this store
        if let lastNotification = recentlyNotifiedStores[userStore.id] {
            let timeSinceLastNotification = Date().timeIntervalSince(lastNotification)
            if timeSinceLastNotification < notificationCooldown {
                // Still in cooldown period
                return
            }
        }

        // Get reminder count for this store
        let reminderCount = storeReminders[userStore.id] ?? 0

        // Only notify if there are incomplete reminders
        guard reminderCount > 0 else {
            return
        }

        // Send notification
        notificationManager.scheduleStoreProximityNotification(
            storeName: userStore.storeName,
            reminderCount: reminderCount
        )

        // Update last notification time
        recentlyNotifiedStores[userStore.id] = Date()

        let distanceInKm = distance / 1000.0
        print("📍 Notified user about \(userStore.storeName) - Distance: \(String(format: "%.2f", distanceInKm))km, Reminders: \(reminderCount)")
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

        lastLocation = location
        checkProximityToStores(userLocation: location)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager error: \(error)")
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        print("Location authorization changed to: \(status.rawValue)")

        // If permission was granted and we have a user ID, start monitoring automatically
        if status == .authorizedAlways, let userId = currentUserId, !isMonitoring {
            startMonitoring(userId: userId)
        } else if status == .authorizedAlways && isMonitoring {
            // Resume monitoring if already configured
            locationManager.startUpdatingLocation()
        }
    }
}
