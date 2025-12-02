//
//  StoreCluster.swift
//  Geolocation_v1.0.0
//
//  Created by Claude on 12/2/25.
//

import Foundation
import MapKit

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

/// Helper class to manage store clustering based on map region
class StoreClusterManager {
    /// Minimum distance (in screen points) below which stores should be clustered
    private let clusterDistanceThreshold: Double = 60.0

    /// Calculate clusters based on the current map region
    func clusterStores(_ userStoreItems: [UserStoreItem], in region: MKCoordinateRegion) -> [StoreAnnotation] {
        // Extract stores with valid coordinates
        var storesWithCoordinates: [(UserStoreItem, CLLocationCoordinate2D)] = []

        for userStoreItem in userStoreItems {
            if let latitude = userStoreItem.store.latitude,
               let longitude = userStoreItem.store.longitude {
                let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
                storesWithCoordinates.append((userStoreItem, coordinate))
            }
        }

        // If too few stores, don't cluster
        if storesWithCoordinates.count <= 1 {
            return storesWithCoordinates.map { .single($0.0, $0.1) }
        }

        // Calculate meters per point for current zoom level
        let metersPerPoint = calculateMetersPerPoint(for: region)
        let clusterDistanceMeters = clusterDistanceThreshold * metersPerPoint

        var annotations: [StoreAnnotation] = []
        var clustered = Set<Int>() // Track which stores have been clustered

        for (index, (userStoreItem, coordinate)) in storesWithCoordinates.enumerated() {
            // Skip if already part of a cluster
            if clustered.contains(index) {
                continue
            }

            // Find nearby stores
            var nearbyStores: [(UserStoreItem, CLLocationCoordinate2D)] = [(userStoreItem, coordinate)]
            var nearbyIndices: [Int] = [index]

            let location1 = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

            for (otherIndex, (otherStoreItem, otherCoordinate)) in storesWithCoordinates.enumerated() {
                // Skip self and already clustered stores
                if otherIndex == index || clustered.contains(otherIndex) {
                    continue
                }

                let location2 = CLLocation(latitude: otherCoordinate.latitude, longitude: otherCoordinate.longitude)
                let distance = location1.distance(from: location2)

                // If within clustering distance, add to cluster
                if distance <= clusterDistanceMeters {
                    nearbyStores.append((otherStoreItem, otherCoordinate))
                    nearbyIndices.append(otherIndex)
                }
            }

            // Mark all stores in this cluster as processed
            nearbyIndices.forEach { clustered.insert($0) }

            // Create annotation
            if nearbyStores.count > 1 {
                // Create cluster
                let centerCoordinate = calculateClusterCenter(nearbyStores.map { $0.1 })
                let userStoreItems = nearbyStores.map { $0.0 }
                annotations.append(.cluster(userStoreItems, centerCoordinate, nearbyStores.count))
            } else {
                // Single store
                annotations.append(.single(nearbyStores[0].0, nearbyStores[0].1))
            }
        }

        return annotations
    }

    /// Calculate the center coordinate of a cluster
    private func calculateClusterCenter(_ coordinates: [CLLocationCoordinate2D]) -> CLLocationCoordinate2D {
        guard !coordinates.isEmpty else {
            return CLLocationCoordinate2D(latitude: 0, longitude: 0)
        }

        let totalLatitude = coordinates.reduce(0.0) { $0 + $1.latitude }
        let totalLongitude = coordinates.reduce(0.0) { $0 + $1.longitude }

        return CLLocationCoordinate2D(
            latitude: totalLatitude / Double(coordinates.count),
            longitude: totalLongitude / Double(coordinates.count)
        )
    }

    /// Calculate how many meters each screen point represents at the current zoom level
    private func calculateMetersPerPoint(for region: MKCoordinateRegion) -> Double {
        // Approximate screen width in points (iPhone average)
        let screenWidthPoints: Double = 375.0

        // Calculate width of visible region in meters at the equator
        let regionWidthMeters = region.span.longitudeDelta * 111000 * cos(region.center.latitude * .pi / 180)

        // Meters per point
        return regionWidthMeters / screenWidthPoints
    }
}
