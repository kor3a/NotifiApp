//
//  TravelTimeService.swift
//  Geolocation_v1.0.0
//
//  Calculates driving time from the user's current location to the nearest
//  physical location of a given store name using MapKit.
//

import Foundation
import CoreLocation
import MapKit

class TravelTimeService {
    static let shared = TravelTimeService()

    private init() {}

    struct TravelEstimate {
        let travelTimeSeconds: TimeInterval
        let distanceMeters: CLLocationDistance
        let storeName: String

        var travelTimeMinutes: Int {
            return max(1, Int(ceil(travelTimeSeconds / 60)))
        }

        var formattedTravelTime: String {
            let minutes = travelTimeMinutes
            if minutes < 60 {
                return "\(minutes) min"
            } else {
                let hours = minutes / 60
                let remainingMinutes = minutes % 60
                if remainingMinutes == 0 {
                    return "\(hours) hr"
                }
                return "\(hours) hr \(remainingMinutes) min"
            }
        }
    }

    /// Calculate the estimated driving time from the user's current location to the nearest
    /// location of the given store name.
    func calculateTravelTime(
        to storeName: String,
        completion: @escaping (Result<TravelEstimate, Error>) -> Void
    ) {
        // Get user's current location from the existing LocationMonitoringManager
        guard let userLocation = LocationMonitoringManager.shared.lastLocation else {
            // Fall back to CLLocationManager's last known location
            let tempManager = CLLocationManager()
            if let location = tempManager.location {
                searchAndCalculate(storeName: storeName, from: location, completion: completion)
            } else {
                completion(.failure(TravelTimeError.locationUnavailable))
            }
            return
        }

        searchAndCalculate(storeName: storeName, from: userLocation, completion: completion)
    }

    private func searchAndCalculate(
        storeName: String,
        from userLocation: CLLocation,
        completion: @escaping (Result<TravelEstimate, Error>) -> Void
    ) {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = storeName
        request.region = MKCoordinateRegion(
            center: userLocation.coordinate,
            latitudinalMeters: 50_000,
            longitudinalMeters: 50_000
        )

        let search = MKLocalSearch(request: request)
        search.start { [weak self] response, error in
            guard let self = self else { return }

            if let error = error {
                completion(.failure(error))
                return
            }

            guard let response = response, !response.mapItems.isEmpty else {
                completion(.failure(TravelTimeError.storeNotFound))
                return
            }

            // Find the nearest store location
            var nearestItem: MKMapItem?
            var nearestDistance: CLLocationDistance = .greatestFiniteMagnitude

            for mapItem in response.mapItems {
                guard let location = mapItem.placemark.location else { continue }
                let distance = userLocation.distance(from: location)
                if distance < nearestDistance {
                    nearestDistance = distance
                    nearestItem = mapItem
                }
            }

            guard let destinationItem = nearestItem else {
                completion(.failure(TravelTimeError.storeNotFound))
                return
            }

            // Calculate driving ETA
            self.calculateDrivingETA(
                from: userLocation,
                to: destinationItem,
                storeName: storeName,
                distance: nearestDistance,
                completion: completion
            )
        }
    }

    private func calculateDrivingETA(
        from userLocation: CLLocation,
        to destination: MKMapItem,
        storeName: String,
        distance: CLLocationDistance,
        completion: @escaping (Result<TravelEstimate, Error>) -> Void
    ) {
        let directionsRequest = MKDirections.Request()
        directionsRequest.source = MKMapItem(
            placemark: MKPlacemark(coordinate: userLocation.coordinate)
        )
        directionsRequest.destination = destination
        directionsRequest.transportType = .automobile

        let directions = MKDirections(request: directionsRequest)
        directions.calculateETA { etaResponse, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let eta = etaResponse else {
                completion(.failure(TravelTimeError.etaUnavailable))
                return
            }

            let estimate = TravelEstimate(
                travelTimeSeconds: eta.expectedTravelTime,
                distanceMeters: distance,
                storeName: storeName
            )
            completion(.success(estimate))
        }
    }

    enum TravelTimeError: LocalizedError {
        case locationUnavailable
        case storeNotFound
        case etaUnavailable

        var errorDescription: String? {
            switch self {
            case .locationUnavailable:
                return "Unable to determine your current location. Please ensure location services are enabled."
            case .storeNotFound:
                return "Could not find a nearby location for this store."
            case .etaUnavailable:
                return "Unable to calculate travel time."
            }
        }
    }
}
