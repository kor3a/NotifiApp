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

        // Check if region changed significantly
        if let lastRegion = lastSearchRegion {
            let centerLatChange = abs(region.center.latitude - lastRegion.center.latitude)
            let centerLonChange = abs(region.center.longitude - lastRegion.center.longitude)
            let spanChange = abs(region.span.latitudeDelta - lastRegion.span.latitudeDelta) / max(lastRegion.span.latitudeDelta, 0.001)

            // Skip if region hasn't changed much
            if centerLatChange < region.span.latitudeDelta * 0.1 &&
               centerLonChange < region.span.longitudeDelta * 0.1 &&
               spanChange < 0.1 {
                // Return cached results
                let allCached = cachedResults.values.flatMap { $0 }
                completion(allCached)
                return
            }
        }

        lastSearchRegion = region

        // Cancel existing tasks
        for task in searchTasks.values {
            task.cancel()
        }
        searchTasks.removeAll()

        // Search for each store
        let dispatchGroup = DispatchGroup()
        var allLocations: [StoreLocation] = []
        let locationsLock = NSLock()

        for userStoreItem in userStoreItems {
            dispatchGroup.enter()

            let task = Task {
                let locations = await searchForStore(userStoreItem, in: region)

                locationsLock.lock()
                allLocations.append(contentsOf: locations)
                cachedResults[userStoreItem.id] = locations
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

            // Filter results to only include items within the visible region
            let filteredItems = response.mapItems.filter { item in
                let coord = item.placemark.coordinate
                return isCoordinate(coord, within: region)
            }

            // Convert to StoreLocation objects
            return filteredItems.prefix(10).map { item in
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
            print("StoreClusterManager: Error searching for \(userStoreItem.store.name): \(error)")
            return []
        }
    }

    /// Check if a coordinate is within the given region
    private func isCoordinate(_ coordinate: CLLocationCoordinate2D, within region: MKCoordinateRegion) -> Bool {
        let latMin = region.center.latitude - region.span.latitudeDelta / 2
        let latMax = region.center.latitude + region.span.latitudeDelta / 2
        let lonMin = region.center.longitude - region.span.longitudeDelta / 2
        let lonMax = region.center.longitude + region.span.longitudeDelta / 2

        return coordinate.latitude >= latMin && coordinate.latitude <= latMax &&
               coordinate.longitude >= lonMin && coordinate.longitude <= lonMax
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
    }

    // Legacy method - kept for compatibility but now returns empty
    func clusterStores(_ userStoreItems: [UserStoreItem], in region: MKCoordinateRegion) -> [StoreAnnotation] {
        return []
    }
}
