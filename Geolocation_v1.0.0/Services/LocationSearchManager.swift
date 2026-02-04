//
//  LocationSearchManager.swift
//  Geolocation_v1.0.0
//
//  Created by Claude on 11/14/25.
//

import Foundation
import CoreLocation
import MapKit

class LocationSearchManager: NSObject, ObservableObject {
    @Published var userLocation: CLLocationCoordinate2D?
    @Published var isLocationAuthorized: Bool = false
    @Published var locationError: String = ""
    @Published var searchResults: [SearchResultStore] = []
    @Published var isSearching: Bool = false

    private let locationManager = CLLocationManager()
    private let searchRadius: CLLocationDistance = 10000 // 10km radius

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
    }

    func requestLocation() {
        locationManager.requestLocation()
    }

    /// Search for places near user's location based on query
    /// Results are grouped by store name - each unique store name appears once
    func searchNearbyStores(query: String) {
        guard !query.isEmpty else {
            DispatchQueue.main.async {
                self.searchResults = []
            }
            return
        }

        guard let userLocation = userLocation else {
            DispatchQueue.main.async {
                self.locationError = "Location not available. Please enable location services."
            }
            return
        }

        DispatchQueue.main.async {
            self.isSearching = true
            self.locationError = ""
        }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.region = MKCoordinateRegion(
            center: userLocation,
            latitudinalMeters: searchRadius * 2,
            longitudinalMeters: searchRadius * 2
        )

        let search = MKLocalSearch(request: request)
        search.start { [weak self] response, error in
            guard let self = self else { return }

            DispatchQueue.main.async {
                self.isSearching = false
            }

            if let error = error {
                print("LocationSearchManager: Search error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.locationError = "Search failed: \(error.localizedDescription)"
                    self.searchResults = []
                }
                return
            }

            guard let response = response else {
                DispatchQueue.main.async {
                    self.searchResults = []
                }
                return
            }

            // Group results by normalized store name
            // Key: normalized name, Value: (displayName, distances array)
            var storeGroups: [String: (displayName: String, distances: [CLLocationDistance])] = [:]

            for mapItem in response.mapItems {
                guard let name = mapItem.name,
                      let location = mapItem.placemark.location else {
                    continue
                }

                let normalizedName = Store.normalizedId(from: name)
                let distance = location.distance(from: CLLocation(
                    latitude: userLocation.latitude,
                    longitude: userLocation.longitude
                ))

                if var existing = storeGroups[normalizedName] {
                    existing.distances.append(distance)
                    storeGroups[normalizedName] = existing
                } else {
                    storeGroups[normalizedName] = (displayName: name, distances: [distance])
                }
            }

            // Convert grouped results to SearchResultStore
            let groupedStores = storeGroups.map { (normalizedName, data) -> SearchResultStore in
                let nearestDistance = data.distances.min() ?? 0
                return SearchResultStore(
                    id: normalizedName,
                    name: data.displayName,
                    nearestDistance: nearestDistance,
                    locationCount: data.distances.count
                )
            }

            // Sort by nearest distance
            let sortedStores = groupedStores.sorted { $0.nearestDistance < $1.nearestDistance }

            DispatchQueue.main.async {
                self.searchResults = sortedStores
                print("LocationSearchManager: Found \(sortedStores.count) unique store names")
            }
        }
    }
}

// MARK: - CLLocationManagerDelegate
extension LocationSearchManager: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        checkLocationAuthorization()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        DispatchQueue.main.async {
            self.userLocation = location.coordinate
            self.isLocationAuthorized = true
            print("LocationSearchManager: Location updated: \(location.coordinate.latitude), \(location.coordinate.longitude)")
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("LocationSearchManager: Location error: \(error.localizedDescription)")
        DispatchQueue.main.async {
            self.locationError = "Failed to get location: \(error.localizedDescription)"
        }
    }

    private func checkLocationAuthorization() {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .restricted:
            DispatchQueue.main.async {
                self.locationError = "Location access is restricted."
                self.isLocationAuthorized = false
            }
        case .denied:
            DispatchQueue.main.async {
                self.locationError = "Location permission denied. Please enable in Settings."
                self.isLocationAuthorized = false
            }
        case .authorizedAlways, .authorizedWhenInUse:
            DispatchQueue.main.async {
                self.isLocationAuthorized = true
                self.locationError = ""
            }
            locationManager.requestLocation()
        @unknown default:
            break
        }
    }
}

// MARK: - SearchResultStore Model
/// Represents a unique store name from search results
/// Groups all locations of the same store chain together
struct SearchResultStore: Identifiable {
    let id: String // Normalized store name as ID
    let name: String
    let nearestDistance: CLLocationDistance // Distance to nearest location in meters
    let locationCount: Int // Number of locations found nearby

    var distanceFormatted: String {
        let miles = nearestDistance * 0.000621371 // Convert meters to miles
        return String(format: "%.1f mi", miles)
    }

    var locationCountFormatted: String {
        if locationCount == 1 {
            return "1 location nearby"
        } else {
            return "\(locationCount) locations nearby"
        }
    }

    /// Convert to Store model for saving to database
    func toStore() -> Store {
        // Use normalized name-based ID so all locations share the same store
        return Store(name: name)
    }
}
