//
//  GooglePlacesService.swift
//  Geolocation_v1.0.0
//
//  Created by Claude on 11/24/25.
//

import Foundation
import CoreLocation

class GooglePlacesService {
    static let shared = GooglePlacesService()

    // IMPORTANT: Replace with your actual Google Places API key
    // Get your API key from: https://console.cloud.google.com/apis/credentials
    private let apiKey = "YOUR_GOOGLE_PLACES_API_KEY"

    private let baseURL = "https://maps.googleapis.com/maps/api/place"

    private init() {}

    /// Find a place by name and location coordinates
    func findPlace(name: String, coordinate: CLLocationCoordinate2D) async throws -> PlaceDetails? {
        // Use Nearby Search to find the place
        let urlString = "\(baseURL)/nearbysearch/json?location=\(coordinate.latitude),\(coordinate.longitude)&radius=50&keyword=\(name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&key=\(apiKey)"

        guard let url = URL(string: urlString) else {
            throw GooglePlacesError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw GooglePlacesError.networkError
        }

        let searchResponse = try JSONDecoder().decode(PlaceSearchResponse.self, from: data)

        guard let firstResult = searchResponse.results.first else {
            return nil
        }

        // If the place has photos, get the first photo reference
        let photoReference = firstResult.photos?.first?.photoReference

        return PlaceDetails(
            placeId: firstResult.placeId,
            name: firstResult.name,
            photoReference: photoReference
        )
    }

    /// Get the photo URL for a place
    func getPhotoURL(photoReference: String, maxWidth: Int = 400) -> String {
        return "\(baseURL)/photo?maxwidth=\(maxWidth)&photo_reference=\(photoReference)&key=\(apiKey)"
    }

    /// Fetch place details and photo URL in one call
    func fetchPlacePhoto(name: String, coordinate: CLLocationCoordinate2D) async throws -> String? {
        guard let placeDetails = try await findPlace(name: name, coordinate: coordinate),
              let photoReference = placeDetails.photoReference else {
            return nil
        }

        return getPhotoURL(photoReference: photoReference)
    }
}

// MARK: - Models

struct PlaceSearchResponse: Codable {
    let results: [PlaceResult]
    let status: String
}

struct PlaceResult: Codable {
    let placeId: String
    let name: String
    let photos: [PlacePhoto]?

    enum CodingKeys: String, CodingKey {
        case placeId = "place_id"
        case name
        case photos
    }
}

struct PlacePhoto: Codable {
    let photoReference: String
    let height: Int
    let width: Int

    enum CodingKeys: String, CodingKey {
        case photoReference = "photo_reference"
        case height
        case width
    }
}

struct PlaceDetails {
    let placeId: String
    let name: String
    let photoReference: String?
}

// MARK: - Errors

enum GooglePlacesError: Error {
    case invalidURL
    case networkError
    case noResults
    case apiKeyMissing

    var localizedDescription: String {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .networkError:
            return "Network error occurred"
        case .noResults:
            return "No results found"
        case .apiKeyMissing:
            return "Google Places API key is missing"
        }
    }
}
