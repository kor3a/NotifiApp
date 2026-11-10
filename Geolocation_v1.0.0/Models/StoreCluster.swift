//
//  StoreCluster.swift
//  Geolocation_v1.0.0
//
//  Created by Claude on 12/2/25.
//

import Foundation
import MapKit

/// Represents a single store location found on the map
struct StoreLocation: Identifiable, Hashable {
    let id: String
    let userStoreItem: UserStoreItem
    let coordinate: CLLocationCoordinate2D
    let placeName: String // The specific location name (e.g., "Walmart Supercenter")
    let address: String?

    static func == (lhs: StoreLocation, rhs: StoreLocation) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

/// Store pins close enough to overlap at the current zoom, drawn as one marker.
/// The store with the most reminders anchors the group and gives it its id, so a
/// group keeps its identity while the map moves and pins join or leave it.
struct StoreLocationGroup: Identifiable {
    /// Every pin in the group, the anchor first and the rest by priority.
    let members: [StoreLocation]

    var anchor: StoreLocation { members[0] }
    var id: String { anchor.id }
    var coordinate: CLLocationCoordinate2D { anchor.coordinate }
    var isGroup: Bool { members.count > 1 }

    /// One saved store behind a group, however many of its branches are in it.
    struct StoreEntry: Identifiable {
        /// The branch nearest the top of the group, which a tap opens.
        let location: StoreLocation
        var branchCount: Int
        var id: String { location.userStoreItem.id }
    }

    /// The stores behind the group, each once, in the group's order.
    var stores: [StoreEntry] {
        var result: [StoreEntry] = []
        for member in members {
            if let index = result.firstIndex(where: { $0.id == member.userStoreItem.id }) {
                result[index].branchCount += 1
            } else {
                result.append(StoreEntry(location: member, branchCount: 1))
            }
        }
        return result
    }

    /// The closest a group's zoom-in goes: about 450 m across.
    static let minimumZoomSpan: CLLocationDegrees = 0.004

    /// Frames every pin in the group, which is close enough to pull them apart.
    var zoomRegion: MKCoordinateRegion {
        let latitudes = members.map { $0.coordinate.latitude }
        let longitudes = members.map { $0.coordinate.longitude }
        let minLat = latitudes.min() ?? coordinate.latitude
        let maxLat = latitudes.max() ?? coordinate.latitude
        let minLon = longitudes.min() ?? coordinate.longitude
        let maxLon = longitudes.max() ?? coordinate.longitude
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude: (minLat + maxLat) / 2,
                longitude: (minLon + maxLon) / 2
            ),
            span: MKCoordinateSpan(
                latitudeDelta: max((maxLat - minLat) * 1.6, Self.minimumZoomSpan),
                longitudeDelta: max((maxLon - minLon) * 1.6, Self.minimumZoomSpan)
            )
        )
    }

    /// Wide enough that two logos in one group would touch or nearly touch.
    private static let radiusPoints: Double = 44

    /// Puts pins that would overlap on a map `mapWidth` points wide showing
    /// `region` into one group each. Matches the Android app's grouping.
    static func grouping(
        _ locations: [StoreLocation],
        in region: MKCoordinateRegion,
        mapWidth: CGFloat
    ) -> [StoreLocationGroup] {
        guard mapWidth > 0 else {
            return locations.map { StoreLocationGroup(members: [$0]) }
        }
        let radiusLon = region.span.longitudeDelta / Double(mapWidth) * radiusPoints
        // A degree of latitude shrinks on screen towards the equator, Mercator-style.
        let radiusLat = radiusLon * cos(region.center.latitude * .pi / 180)

        // The ids break ties so the same pin anchors every time.
        let ordered = locations.sorted { a, b in
            let aCount = a.userStoreItem.store.reminderCount
            let bCount = b.userStoreItem.store.reminderCount
            return aCount != bCount ? aCount > bCount : a.id < b.id
        }

        var groups: [[StoreLocation]] = []
        for location in ordered {
            let nearby = groups.firstIndex { group in
                abs(group[0].coordinate.latitude - location.coordinate.latitude) <= radiusLat &&
                abs(group[0].coordinate.longitude - location.coordinate.longitude) <= radiusLon
            }
            if let nearby {
                groups[nearby].append(location)
            } else {
                groups.append([location])
            }
        }
        return groups.map { StoreLocationGroup(members: $0) }
    }
}

/// Represents either a single store or a cluster of multiple stores
enum StoreAnnotation: Identifiable, Hashable {
    case single(UserStoreItem, CLLocationCoordinate2D)
    case cluster([UserStoreItem], CLLocationCoordinate2D, Int) // stores, center coordinate, count

    var id: String {
        switch self {
        case .single(let userStoreItem, _):
            return userStoreItem.id
        case .cluster(let stores, _, _):
            // Create a unique ID from all store IDs in the cluster
            return "cluster_" + stores.map { $0.id }.sorted().joined(separator: "_")
        }
    }

    var coordinate: CLLocationCoordinate2D {
        switch self {
        case .single(_, let coordinate):
            return coordinate
        case .cluster(_, let coordinate, _):
            return coordinate
        }
    }

    var stores: [UserStoreItem] {
        switch self {
        case .single(let store, _):
            return [store]
        case .cluster(let stores, _, _):
            return stores
        }
    }

    var count: Int {
        switch self {
        case .single:
            return 1
        case .cluster(_, _, let count):
            return count
        }
    }

    static func == (lhs: StoreAnnotation, rhs: StoreAnnotation) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

/// Helper class to manage store location search based on map region
/// Searches for nearby locations of saved stores using MKLocalSearch
class StoreClusterManager {
    private var searchTasks: [String: Task<Void, Never>] = [:]
    private var cachedResults: [String: [StoreLocation]] = [:]
    private var lastSearchRegion: MKCoordinateRegion?
    private var lastSearchCenter: CLLocationCoordinate2D?

    /// Search for nearby locations of saved stores in the current map region
    /// - Parameters:
    ///   - userStoreItems: The user's saved stores
    ///   - region: The current visible map region
    ///   - completion: Called with found store locations
    func searchNearbyStores(_ userStoreItems: [UserStoreItem], in region: MKCoordinateRegion, completion: @escaping ([StoreLocation]) -> Void) {
        // Skip if no stores
        guard !userStoreItems.isEmpty else {
            completion([])
            return
        }

        // Only re-search when the map center has moved significantly (panning).
        // Zoom-only changes reuse cached results so pins don't vanish mid-pinch.
        if let lastRegion = lastSearchRegion, let lastCenter = lastSearchCenter {
            let centerLatChange = abs(region.center.latitude - lastCenter.latitude)
            let centerLonChange = abs(region.center.longitude - lastCenter.longitude)

            // Use the larger of the two spans so zooming in doesn't shrink the threshold
            let referenceSpan = max(region.span.latitudeDelta, lastRegion.span.latitudeDelta)
            let referenceLonSpan = max(region.span.longitudeDelta, lastRegion.span.longitudeDelta)

            let centerMovedSignificantly = centerLatChange > referenceSpan * 0.25 ||
                                           centerLonChange > referenceLonSpan * 0.25

            if !centerMovedSignificantly {
                // Center hasn't moved much — return cached results
                let allCached = cachedResults.values.flatMap { $0 }
                if !allCached.isEmpty {
                    completion(allCached)
                    return
                }
                // Cache is empty, fall through to search
            }
        }

        lastSearchRegion = region
        lastSearchCenter = region.center

        // Cancel existing tasks
        for task in searchTasks.values {
            task.cancel()
        }
        searchTasks.removeAll()

        // Use an expanded search region (3x visible area) so stores just outside
        // the viewport are still found and don't vanish at the edges.
        let expandedRegion = MKCoordinateRegion(
            center: region.center,
            span: MKCoordinateSpan(
                latitudeDelta: region.span.latitudeDelta * 3,
                longitudeDelta: region.span.longitudeDelta * 3
            )
        )

        // Search for each store
        let dispatchGroup = DispatchGroup()
        var allLocations: [StoreLocation] = []
        let locationsLock = NSLock()

        for userStoreItem in userStoreItems {
            dispatchGroup.enter()

            let task = Task {
                let locations = await searchForStore(userStoreItem, in: expandedRegion)

                locationsLock.lock()
                // Only update cache for this store if we got results;
                // keep old cached results if the search returned empty
                // (avoids wiping pins due to throttled/failed searches).
                if !locations.isEmpty {
                    cachedResults[userStoreItem.id] = locations
                }
                allLocations.append(contentsOf: cachedResults[userStoreItem.id] ?? [])
                locationsLock.unlock()

                dispatchGroup.leave()
            }

            searchTasks[userStoreItem.id] = task
        }

        dispatchGroup.notify(queue: .main) {
            completion(allLocations)
        }
    }

    /// Search for a specific store in the given region
    private func searchForStore(_ userStoreItem: UserStoreItem, in region: MKCoordinateRegion) async -> [StoreLocation] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = userStoreItem.store.name
        request.region = region
        request.resultTypes = .pointOfInterest

        do {
            let search = MKLocalSearch(request: request)
            let response = try await search.start()

            // MapKit's search is fuzzy: with no real match nearby it returns lookalikes
            // ("Save Mart" for "H Mart"), which would get pinned under the saved store's
            // logo. Keep only results that name the saved store, as geofencing does.
            let normalizedSearchName = Store.normalizedId(from: userStoreItem.store.name)
            let matchingItems = response.mapItems.filter { item in
                guard let itemName = item.name else { return false }
                return LocationMonitoringManager.storeNamesMatch(
                    normalizedSearchName,
                    Store.normalizedId(from: itemName)
                )
            }

            // Convert to StoreLocation objects — no strict visible-region filter
            // so pins persist when zooming in/out.
            return matchingItems.prefix(10).map { item in
                // Capture the place record's website so logos resolve from the store's
                // real domain instead of one guessed from its name.
                StoreLogoProvider.shared.recordPlaceWebsite(
                    storeName: item.name ?? userStoreItem.store.name,
                    url: item.url
                )

                let coord = item.placemark.coordinate
                let address = formatAddress(from: item.placemark)
                let uniqueId = "\(userStoreItem.id)_\(coord.latitude)_\(coord.longitude)"

                return StoreLocation(
                    id: uniqueId,
                    userStoreItem: userStoreItem,
                    coordinate: coord,
                    placeName: item.name ?? userStoreItem.store.name,
                    address: address
                )
            }
        } catch {
            #if DEBUG
            print("StoreClusterManager: Error searching for \(userStoreItem.store.name): \(error)")
            #endif
            return []
        }
    }

    /// Format address from placemark
    private func formatAddress(from placemark: MKPlacemark) -> String? {
        var components: [String] = []

        if let thoroughfare = placemark.thoroughfare {
            if let subThoroughfare = placemark.subThoroughfare {
                components.append("\(subThoroughfare) \(thoroughfare)")
            } else {
                components.append(thoroughfare)
            }
        }

        if let locality = placemark.locality {
            components.append(locality)
        }

        return components.isEmpty ? nil : components.joined(separator: ", ")
    }

    /// Clear cached results
    func clearCache() {
        cachedResults.removeAll()
        lastSearchRegion = nil
        lastSearchCenter = nil
    }

    // Legacy method - kept for compatibility but now returns empty
    func clusterStores(_ userStoreItems: [UserStoreItem], in region: MKCoordinateRegion) -> [StoreAnnotation] {
        return []
    }
}
