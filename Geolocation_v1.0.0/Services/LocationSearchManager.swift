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

            // Convert MKMapItem results to SearchResultStore
            let stores = response.mapItems.compactMap { mapItem -> SearchResultStore? in
                guard let name = mapItem.name,
                      let location = mapItem.placemark.location else {
                    return nil
                }

                // Build address string
                let placemark = mapItem.placemark
                var addressComponents: [String] = []

                if let street = placemark.thoroughfare {
                    if let streetNumber = placemark.subThoroughfare {
                        addressComponents.append("\(streetNumber) \(street)")
                    } else {
                        addressComponents.append(street)
                    }
                }
                if let city = placemark.locality {
                    addressComponents.append(city)
                }
                if let state = placemark.administrativeArea {
                    addressComponents.append(state)
                }
                if let zip = placemark.postalCode {
                    addressComponents.append(zip)
                }

                let address = addressComponents.isEmpty ? "Address unavailable" : addressComponents.joined(separator: ", ")

                // Calculate distance from user
                let distance = location.distance(from: CLLocation(
                    latitude: userLocation.latitude,
                    longitude: userLocation.longitude
                ))

                return SearchResultStore(
                    name: name,
                    address: address,
                    coordinate: location.coordinate,
                    distance: distance,
                    phoneNumber: mapItem.phoneNumber
                )
            }

            // Sort by distance
            let sortedStores = stores.sorted { $0.distance < $1.distance }

            DispatchQueue.main.async {
                self.searchResults = sortedStores
                print("LocationSearchManager: Found \(sortedStores.count) nearby stores")
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
struct SearchResultStore: Identifiable {
    let id = UUID()
    let name: String
    let address: String
    let coordinate: CLLocationCoordinate2D
    let distance: CLLocationDistance // in meters
    let phoneNumber: String?

    var distanceFormatted: String {
        let miles = distance * 0.000621371 // Convert meters to miles
        if miles < 1 {
            return String(format: "%.1f mi", miles)
        } else {
            return String(format: "%.1f mi", miles)
        }
    }

    /// Convert to Store model for saving to database
    func toStore() -> Store {
        // Generate a consistent ID based on name and coordinate
        let idString = "\(name)-\(coordinate.latitude)-\(coordinate.longitude)"
        let id = idString.replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: ".", with: "")
            .lowercased()

        return Store(
            id: id,
            name: name,
            address: address,
            reminderCount: 0,
            sortOrder: nil,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )
    }
}
