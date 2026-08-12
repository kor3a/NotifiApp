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
import UIKit

class LocationMonitoringManager: NSObject, ObservableObject {
    static let shared = LocationMonitoringManager()

    private let locationManager = CLLocationManager()
    private let db = Firestore.firestore()
    private let notificationManager = NotificationManager.shared

    // Distance threshold in meters for proximity notification (geofence radius)
    private let proximityThreshold: CLLocationDistance = 150

    /// How far out to look for store locations worth monitoring. Generous on
    /// purpose: the notification still only fires inside a 150m fence, so a wider
    /// search costs nothing but eligibility, and the region budget is usually
    /// under-spent rather than over-subscribed. Stores a 15-minute drive away are
    /// exactly the ones a "you're passing it" reminder is useful for.
    private let searchRadius: CLLocationDistance = 15000

    // Track recently notified stores to avoid spam (normalized store name -> last notification time)
    private var recentlyNotifiedStores: [String: Date] = [:]
    private let notificationCooldown: TimeInterval = 3600 // 1 hour cooldown

    // Store names with a count fetch in flight, so overlapping region entries for
    // the same store don't stack up. Kept separate from `recentlyNotifiedStores`:
    // an in-flight check must never consume the hour-long cooldown, or a fetch that
    // fails silences the store until it expires.
    private var proximityChecksInFlight: Set<String> = []

    // Hard ceiling on the pre-notification count fetch. A geofence wake gets only a
    // few seconds of background runtime, and Firestore has to rebuild its connection
    // after suspension — past this we notify from the cached count instead of
    // dropping the notification entirely.
    private let liveCountTimeout: TimeInterval = 4

    // Maps geofence region identifiers to the normalized store name they cover.
    // A name can have several user_store rows behind it (e.g. an owned list plus
    // one shared from a friend), so regions map to the name rather than to a
    // single row and the counts are resolved at notification time.
    private var regionToStoreName: [String: String] = [:]

    // Debounce geofence refresh so we don't hammer MapKit on every significant change
    private var lastGeofenceRefreshTime: Date?
    private let geofenceRefreshDebounce: TimeInterval = 300 // Refresh at most every 5 minutes

    /// Core Location caps an app at 20 simultaneously monitored regions. This is a
    /// system limit — there's no entitlement that raises it — so the budget has to
    /// be allocated to the stores most likely to matter.
    private let maxMonitoredRegions = 20

    /// Ceiling on how many locations of the same store can hold regions at once, so
    /// one dense chain can't consume the whole budget.
    private let maxLocationsPerStore = 2

    /// A store's second location only earns a slot when it's this close; beyond it,
    /// the nearest one is enough.
    private let secondLocationMaxDistance: CLLocationDistance = 2500

    // Guards against overlapping refreshes, since a refresh now spans every store's
    // MapKit search before anything is registered.
    private var isRefreshingGeofences = false

    // Coalesces the burst of reminder-count updates that arrives on initial load
    // into a single re-prioritization.
    private var pendingPriorityRefresh: DispatchWorkItem?
    private let priorityRefreshCoalesceDelay: TimeInterval = 2

    @Published var isMonitoring = false
    @Published var lastLocation: CLLocation?

    /// Mirrors `locationManager.authorizationStatus` so views can react to the
    /// user answering the system prompt — `requestLocationPermission()` has no
    /// completion handler, and the answer only arrives via the delegate.
    @Published private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined

    private var userStores: [UserStore] = []
    private var storeReminders: [String: Int] = [:] // reminderStoreId -> incomplete reminder count

    // Firestore listeners, retained so they can be torn down instead of stacking
    // up every time the store list changes.
    private var userStoresListener: ListenerRegistration?
    private var reminderCountListeners: [String: ListenerRegistration] = [:] // reminderStoreId -> listener
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
        authorizationStatus = locationManager.authorizationStatus
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
        #if DEBUG
        print("🔵 LocationMonitoring: startMonitoring called for userId: \(userId)")
        #endif

        // Already running for this account — nothing to rebuild.
        if isMonitoring, currentUserId == userId {
            #if DEBUG
            print("   ↩️ Already monitoring for \(userId)")
            #endif
            return
        }

        // A different account is taking over. The restored-from-UserDefaults ID
        // starts monitoring before the session is known, so this is the point where
        // the real signed-in user displaces it. Tear the previous user's geofences,
        // listeners, stores and counts down rather than layering on top of them.
        if let previousUserId = currentUserId, previousUserId != userId {
            #if DEBUG
            print("   🔁 Switching monitored user: \(previousUserId) → \(userId)")
            #endif
            stopMonitoring()
        }

        currentUserId = userId

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
        userStoresListener?.remove()
        userStoresListener = nil
        removeAllReminderCountListeners()

        // Everything below is per-account. Leaving any of it behind lets one user's
        // stores drive another user's notifications.
        userStores.removeAll()
        proximityChecksInFlight.removeAll()
        recentlyNotifiedStores.removeAll()
        lastGeofenceRefreshTime = nil
        pendingPriorityRefresh?.cancel()
        pendingPriorityRefresh = nil
        isRefreshingGeofences = false

        #if DEBUG
        print("Stopped location monitoring")
        #endif
    }

    /// Stop monitoring and forget the account entirely, including the user ID
    /// persisted for background launches. Call this on sign-out — otherwise the
    /// next launch restores the signed-out user and geofences their stores.
    func clearUser() {
        stopMonitoring()
        currentUserId = nil
        #if DEBUG
        print("🧹 LocationMonitoring: Cleared stored user")
        #endif
    }

    // MARK: - Geofence Management

    private func stopAllGeofences() {
        for region in locationManager.monitoredRegions {
            locationManager.stopMonitoring(for: region)
        }
        regionToStoreName.removeAll()
        #if DEBUG
        print("🗺️ LocationMonitoring: Removed all geofences")
        #endif
    }

    /// One candidate location for a store, before the region budget is allocated.
    private struct GeofenceCandidate {
        let storeName: String
        let normalizedName: String
        let coordinate: CLLocationCoordinate2D
        let distance: CLLocationDistance
        let hasReminders: Bool
    }

    /// Re-evaluate geofences around the given location. Called on initial location
    /// fix, after significant location changes, and when reminder counts change the
    /// priority ordering.
    ///
    /// Every store is searched first and the results are ranked together, because
    /// the region budget is scarce and has to be spent deliberately — registering
    /// as each search returns hands the whole budget to whichever chain MapKit
    /// answers for first.
    private func refreshGeofences(for location: CLLocation) {
        // Debounce: avoid hammering MapKit on rapid successive calls
        if let last = lastGeofenceRefreshTime,
           Date().timeIntervalSince(last) < geofenceRefreshDebounce {
            #if DEBUG
            print("🗺️ LocationMonitoring: Skipping geofence refresh (debounce)")
            #endif
            return
        }

        guard !isRefreshingGeofences else {
            #if DEBUG
            print("🗺️ LocationMonitoring: Deferring geofence refresh (already in progress)")
            #endif
            // Re-arm rather than drop it, or a priority change that lands during a
            // refresh is lost until the user next moves.
            requestGeofenceRefreshForPriorityChange()
            return
        }

        let storeNames = Set(userStores.map { $0.storeName })
        guard !storeNames.isEmpty else {
            #if DEBUG
            print("⚠️ LocationMonitoring: No stores to geofence")
            #endif
            return
        }

        lastGeofenceRefreshTime = Date()
        isRefreshingGeofences = true

        #if DEBUG
        print("🗺️ LocationMonitoring: Refreshing geofences for \(storeNames.count) store name(s)")
        #endif

        var candidates: [GeofenceCandidate] = []
        let candidatesLock = NSLock()
        let group = DispatchGroup()

        for storeName in storeNames {
            group.enter()
            searchCandidates(for: storeName, near: location) { found in
                candidatesLock.lock()
                candidates.append(contentsOf: found)
                candidatesLock.unlock()
                group.leave()
            }
        }

        group.notify(queue: .main) { [weak self] in
            guard let self = self else { return }

            // stopMonitoring clears this flag, so a user switch or a stop that
            // landed while the searches were in flight cancels the registration —
            // otherwise the previous account's stores get geofenced.
            guard self.isRefreshingGeofences else {
                #if DEBUG
                print("🗺️ LocationMonitoring: Discarding geofence refresh (cancelled mid-flight)")
                #endif
                return
            }
            self.isRefreshingGeofences = false

            guard self.isMonitoring else { return }
            self.registerGeofences(from: candidates)
        }
    }

    /// Search MapKit for a store by name near the user and return every matching
    /// location within the search radius. Registers nothing — allocation happens
    /// once all searches are in.
    private func searchCandidates(
        for storeName: String,
        near userLocation: CLLocation,
        completion: @escaping ([GeofenceCandidate]) -> Void
    ) {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = storeName
        request.region = MKCoordinateRegion(
            center: userLocation.coordinate,
            latitudinalMeters: searchRadius * 2,
            longitudinalMeters: searchRadius * 2
        )

        let search = MKLocalSearch(request: request)
        search.start { [weak self] response, error in
            guard let self = self else {
                completion([])
                return
            }

            if let error = error {
                #if DEBUG
                print("   ❌ Geofence search error for '\(storeName)': \(error.localizedDescription)")
                #endif
                completion([])
                return
            }

            guard let response = response else {
                completion([])
                return
            }

            let normalizedSearchName = Store.normalizedId(from: storeName)
            let hasReminders = self.hasIncompleteReminders(forNormalizedName: normalizedSearchName)

            var found: [GeofenceCandidate] = []

            for mapItem in response.mapItems {
                guard let itemName = mapItem.name,
                      let itemLocation = mapItem.placemark.location else { continue }

                // Only consider results whose name matches the saved store name
                let normalizedResultName = Store.normalizedId(from: itemName)
                guard Self.storeNamesMatch(normalizedSearchName, normalizedResultName) else { continue }

                // Only geofence stores within the search radius
                let distance = userLocation.distance(from: itemLocation)
                guard distance <= self.searchRadius else { continue }

                found.append(GeofenceCandidate(
                    storeName: storeName,
                    normalizedName: normalizedSearchName,
                    coordinate: mapItem.placemark.coordinate,
                    distance: distance,
                    hasReminders: hasReminders
                ))
            }

            #if DEBUG
            if found.isEmpty {
                // A store that yields nothing is invisible to the allocator, which is
                // indistinguishable from "no slot available" without this. Show what
                // MapKit actually returned so the reason is obvious.
                let rejected = response.mapItems.prefix(5).map { item -> String in
                    let name = item.name ?? "(unnamed)"
                    guard let loc = item.placemark.location else { return "'\(name)' (no location)" }
                    return "'\(name)' @\(Int(userLocation.distance(from: loc)))m"
                }
                print("   🔎 No candidates for '\(storeName)' from \(response.mapItems.count) result(s): \(rejected.joined(separator: ", "))")
            }
            #endif

            completion(found)
        }
    }

    /// Spend the region budget: cap how many locations any one store name can take,
    /// then rank stores with reminders ahead of empty ones and nearer ahead of
    /// farther.
    private func registerGeofences(from candidates: [GeofenceCandidate]) {
        // Every search came back empty — most likely MapKit rate-limited us. Keep
        // the regions already registered rather than tearing them down for nothing.
        guard !candidates.isEmpty else {
            #if DEBUG
            print("⚠️ LocationMonitoring: No candidates found, keeping \(locationManager.monitoredRegions.count) existing region(s)")
            #endif
            return
        }

        var byName: [String: [GeofenceCandidate]] = [:]
        for candidate in candidates {
            byName[candidate.normalizedName, default: []].append(candidate)
        }

        // Per-name cap. A store gets its nearest location outright; a second only
        // earns a slot when it's close enough to plausibly be on the user's routine.
        var shortlist: [GeofenceCandidate] = []
        for (_, locations) in byName {
            for (index, candidate) in locations.sorted(by: { $0.distance < $1.distance }).enumerated() {
                guard index < maxLocationsPerStore else { break }
                guard index == 0 || candidate.distance <= secondLocationMaxDistance else { break }
                shortlist.append(candidate)
            }
        }

        // Stores with something waiting in them win the budget; distance breaks ties.
        shortlist.sort {
            if $0.hasReminders != $1.hasReminders { return $0.hasReminders }
            return $0.distance < $1.distance
        }

        let selected = Array(shortlist.prefix(maxMonitoredRegions))

        // Swap old fences for new only now that the replacements are known, so the
        // user is never left with nothing monitored while searches are in flight.
        stopAllGeofences()

        for candidate in selected {
            // Use a UUID-keyed identifier to avoid parsing store names back out of strings
            let identifier = UUID().uuidString
            let region = CLCircularRegion(
                center: candidate.coordinate,
                radius: proximityThreshold,
                identifier: identifier
            )
            region.notifyOnEntry = true
            region.notifyOnExit = false

            regionToStoreName[identifier] = candidate.normalizedName
            locationManager.startMonitoring(for: region)

            #if DEBUG
            let tag = candidate.hasReminders ? "📝" : "  "
            print("   📍 \(tag) Geofenced '\(candidate.storeName)' at \(Int(candidate.distance))m away (id: \(identifier.prefix(8))…)")
            #endif
        }

        #if DEBUG
        print("🗺️ LocationMonitoring: Registered \(selected.count)/\(maxMonitoredRegions) regions from \(candidates.count) candidate location(s)")
        for candidate in shortlist.dropFirst(selected.count) {
            print("   ⏭️ No region slot for '\(candidate.storeName)' at \(Int(candidate.distance))m (\(candidate.hasReminders ? "has reminders" : "empty"))")
        }
        #endif
    }

    /// Whether a MapKit result names the same store the user saved.
    ///
    /// Exact equality is too strict: MapKit routinely returns a branch-qualified
    /// name for the same POI ("H Mart Rancho Cucamonga" for a store saved as
    /// "H Mart"), and can return the shorter form for one saved longer. Either name
    /// being a prefix of the other covers both without matching unrelated stores.
    static func storeNamesMatch(_ normalizedA: String, _ normalizedB: String) -> Bool {
        if normalizedA == normalizedB { return true }
        guard !normalizedA.isEmpty, !normalizedB.isEmpty else { return false }
        return normalizedA.hasPrefix(normalizedB) || normalizedB.hasPrefix(normalizedA)
    }

    /// Whether any list behind this store name currently has incomplete reminders.
    private func hasIncompleteReminders(forNormalizedName normalizedName: String) -> Bool {
        let reminderStoreIds = Set(
            userStores
                .filter { Store.normalizedId(from: $0.storeName) == normalizedName }
                .compactMap { $0.reminderStoreId }
        )
        return reminderStoreIds.contains { (storeReminders[$0] ?? 0) > 0 }
    }

    /// Reminder counts decide which stores deserve the scarce region slots, so a
    /// list gaining its first item — or losing its last — can change the allocation.
    /// Coalesced, because the initial load delivers a burst of count updates.
    private func requestGeofenceRefreshForPriorityChange() {
        guard let location = lastLocation else { return }

        pendingPriorityRefresh?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            // Priorities changed rather than the user moving, so the movement
            // debounce shouldn't suppress this.
            self.lastGeofenceRefreshTime = nil
            self.refreshGeofences(for: location)
        }
        pendingPriorityRefresh = work
        DispatchQueue.main.asyncAfter(deadline: .now() + priorityRefreshCoalesceDelay, execute: work)
    }

    // MARK: - Data Loading

    private func loadUserStores(userId: String) {
        #if DEBUG
        print("🔄 LocationMonitoring: Loading user stores for userId: \(userId)")
        #endif

        // Replace any previous listener so repeated startMonitoring() calls don't stack
        userStoresListener?.remove()
        userStoresListener = db.collection("user_stores")
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
        var reminderStoreIds: Set<String> = []
        for userStore in userStores {
            guard let reminderStoreId = userStore.reminderStoreId else {
                #if DEBUG
                print("⚠️ LocationMonitoring: Store '\(userStore.storeName)' has no ID, skipping")
                #endif
                continue
            }
            reminderStoreIds.insert(reminderStoreId)
        }

        // Tear down listeners for lists we no longer track, and drop their counts
        for (id, listener) in reminderCountListeners where !reminderStoreIds.contains(id) {
            listener.remove()
            reminderCountListeners.removeValue(forKey: id)
            storeReminders.removeValue(forKey: id)
        }

        // Register a listener for each list we aren't already watching
        for reminderStoreId in reminderStoreIds where reminderCountListeners[reminderStoreId] == nil {
            let listener = db.collection("reminders")
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
                    let previousCount = self.storeReminders[reminderStoreId]
                    self.storeReminders[reminderStoreId] = count
                    #if DEBUG
                    print("LocationMonitoring: List '\(reminderStoreId)' has \(count) incomplete reminders")
                    #endif

                    // Whether a list is empty decides who gets a region slot, so a
                    // change here can change the allocation.
                    if previousCount != count {
                        self.requestGeofenceRefreshForPriorityChange()
                    }
                }

            reminderCountListeners[reminderStoreId] = listener
        }
    }

    private func removeAllReminderCountListeners() {
        for (_, listener) in reminderCountListeners {
            listener.remove()
        }
        reminderCountListeners.removeAll()
        storeReminders.removeAll()
    }

    /// Read the current incomplete-reminder count straight from Firestore rather
    /// than trusting `storeReminders`. Snapshot listeners are disconnected while
    /// the app is suspended, so the cached counts can be hours stale by the time a
    /// geofence wakes us — which is exactly when we're about to notify.
    ///
    /// Best-effort only: the completion always runs. Any list whose fetch errors
    /// falls back to its cached value, and if the whole fetch outlives
    /// `liveCountTimeout` the cached total is used. Getting a slightly stale count
    /// out is better than getting nothing out.
    private func fetchLiveReminderCount(
        for reminderStoreIds: Set<String>,
        completion: @escaping (Int) -> Void
    ) {
        let group = DispatchGroup()
        var total = 0
        let totalLock = NSLock()

        // Deliver exactly once, whichever of the fetch and the timeout lands first.
        // Both paths run on main, so the flag needs no synchronization.
        var didComplete = false
        let finish: (Int) -> Void = { count in
            guard !didComplete else { return }
            didComplete = true
            completion(count)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + liveCountTimeout) { [weak self] in
            guard !didComplete, let self = self else { return }
            let cached = reminderStoreIds.reduce(0) { $0 + (self.storeReminders[$1] ?? 0) }
            #if DEBUG
            print("⏱️ LocationMonitoring: Live count timed out, falling back to cached (\(cached))")
            #endif
            finish(cached)
        }

        for reminderStoreId in reminderStoreIds {
            group.enter()
            db.collection("reminders")
                .whereField("userStoreId", isEqualTo: reminderStoreId)
                .whereField("isDone", isEqualTo: false)
                .getDocuments { [weak self] snapshot, error in
                    defer { group.leave() }
                    guard let self = self else { return }

                    let count: Int
                    if let error = error {
                        #if DEBUG
                        print("⚠️ LocationMonitoring: Live count failed for '\(reminderStoreId)', using cached: \(error)")
                        #endif
                        count = self.storeReminders[reminderStoreId] ?? 0
                    } else {
                        count = snapshot?.documents.count ?? 0
                        self.storeReminders[reminderStoreId] = count
                    }

                    totalLock.lock()
                    total += count
                    totalLock.unlock()
                }
        }

        group.notify(queue: .main) {
            finish(total)
        }
    }

    // MARK: - Proximity Handling

    private func handleStoreProximity(normalizedStoreName: String) {
        // Every list the user keeps under this store name — an owned one, plus any
        // shared with them — counts toward what's waiting for them at this location.
        let matchingStores = userStores.filter {
            Store.normalizedId(from: $0.storeName) == normalizedStoreName
        }

        guard let displayStore = matchingStores.first else {
            #if DEBUG
            print("⚠️ LocationMonitoring: No user store found named '\(normalizedStoreName)'")
            #endif
            return
        }

        // Cooldown check
        if let lastNotification = recentlyNotifiedStores[normalizedStoreName] {
            let timeSinceLastNotification = Date().timeIntervalSince(lastNotification)
            guard timeSinceLastNotification >= notificationCooldown else {
                #if DEBUG
                let minutesAgo = Int(timeSinceLastNotification / 60)
                print("⏸️ LocationMonitoring: In cooldown for '\(displayStore.storeName)' (notified \(minutesAgo) min ago)")
                #endif
                return
            }
        }

        // Distinct lists only — two rows can point at the same shared list, and
        // counting it twice would inflate the number in the notification.
        let reminderStoreIds = Set(matchingStores.compactMap { $0.reminderStoreId })
        guard !reminderStoreIds.isEmpty else { return }

        // Hold off duplicate region entries while a check runs, without touching the
        // cooldown — the cooldown is only stamped once a notification actually goes out.
        guard !proximityChecksInFlight.contains(normalizedStoreName) else {
            #if DEBUG
            print("⏸️ LocationMonitoring: Check already in flight for '\(displayStore.storeName)'")
            #endif
            return
        }
        proximityChecksInFlight.insert(normalizedStoreName)

        // Keep the app alive long enough to finish the count and schedule. Without
        // this, a geofence wake can be suspended mid-fetch and deliver nothing.
        var backgroundTask: UIBackgroundTaskIdentifier = .invalid
        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "StoreProximityCount") {
            if backgroundTask != .invalid {
                UIApplication.shared.endBackgroundTask(backgroundTask)
                backgroundTask = .invalid
            }
        }

        fetchLiveReminderCount(for: reminderStoreIds) { [weak self] reminderCount in
            defer {
                if backgroundTask != .invalid {
                    UIApplication.shared.endBackgroundTask(backgroundTask)
                    backgroundTask = .invalid
                }
            }

            guard let self = self else { return }
            self.proximityChecksInFlight.remove(normalizedStoreName)

            guard reminderCount > 0 else {
                #if DEBUG
                print("❌ LocationMonitoring: No incomplete reminders for '\(displayStore.storeName)' - skipping")
                #endif
                return
            }

            // Stamp the cooldown only now that something is actually being sent.
            self.recentlyNotifiedStores[normalizedStoreName] = Date()

            self.notificationManager.scheduleStoreProximityNotification(
                storeName: displayStore.storeName,
                reminderCount: reminderCount
            )

            #if DEBUG
            print("✅ LocationMonitoring: Notification sent for '\(displayStore.storeName)' (\(reminderCount) reminders)")
            #endif
        }
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
        // Hop to main before touching the region map and reminder counts — the
        // Firestore callbacks that write them land on the main queue, and the live
        // count fetch completes there too.
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            guard let normalizedStoreName = self.regionToStoreName[region.identifier] else {
                #if DEBUG
                print("⚠️ LocationMonitoring: Entered unknown region \(region.identifier.prefix(8))…")
                #endif
                return
            }

            #if DEBUG
            print("📍 LocationMonitoring: Entered geofence for '\(normalizedStoreName)'")
            #endif

            self.handleStoreProximity(normalizedStoreName: normalizedStoreName)
        }
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

        DispatchQueue.main.async {
            self.authorizationStatus = status
        }

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
