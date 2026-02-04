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
/// NOTE: Since stores are now name-based (not location-based), this manager returns empty results.
/// The map will only show search results, not saved stores.
class StoreClusterManager {
    /// Calculate clusters based on the current map region
    /// Returns empty since stores no longer have fixed coordinates
    func clusterStores(_ userStoreItems: [UserStoreItem], in region: MKCoordinateRegion) -> [StoreAnnotation] {
        // Stores are now name-based without coordinates, so no map annotations
        return []
    }
}
