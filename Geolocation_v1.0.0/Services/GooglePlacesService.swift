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
    private let apiKey = "AIzaSyCEd71bzy36JdYwAvrQ7LELqHarijNJ7ds"

    private let baseURL = "https://maps.googleapis.com/maps/api/place"

    private init() {}

    /// Find a place by name and location coordinates
    func findPlace(name: String, coordinate: CLLocationCoordinate2D) async throws -> PlaceDetails? {
        print("🔍 GooglePlaces: Searching for '\(name)' at \(coordinate.latitude), \(coordinate.longitude)")

        // Use Nearby Search to find the place with a larger radius
        let urlString = "\(baseURL)/nearbysearch/json?location=\(coordinate.latitude),\(coordinate.longitude)&radius=100&keyword=\(name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&key=\(apiKey)"

        print("🌐 GooglePlaces: Request URL: \(urlString.replacingOccurrences(of: apiKey, with: "***API_KEY***"))")

        guard let url = URL(string: urlString) else {
            print("❌ GooglePlaces: Invalid URL")
            throw GooglePlacesError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ GooglePlaces: Invalid HTTP response")
            throw GooglePlacesError.networkError
        }

        print("📡 GooglePlaces: HTTP Status Code: \(httpResponse.statusCode)")

        guard httpResponse.statusCode == 200 else {
            if let errorString = String(data: data, encoding: .utf8) {
                print("❌ GooglePlaces: API Error Response: \(errorString)")
            }
            throw GooglePlacesError.networkError
        }

        // Print raw response for debugging
        if let jsonString = String(data: data, encoding: .utf8) {
            print("📦 GooglePlaces: Raw Response: \(jsonString)")
        }

        let searchResponse = try JSONDecoder().decode(PlaceSearchResponse.self, from: data)

        print("✅ GooglePlaces: API Status: \(searchResponse.status)")
        print("📊 GooglePlaces: Found \(searchResponse.results.count) results")

        guard let firstResult = searchResponse.results.first else {
            print("⚠️ GooglePlaces: No results found for '\(name)'")
            return nil
        }

        print("🏪 GooglePlaces: First result: \(firstResult.name)")
        print("📸 GooglePlaces: Photos available: \(firstResult.photos?.count ?? 0)")

        // If the place has photos, get the first photo reference
        let photoReference = firstResult.photos?.first?.photoReference

        if let photoRef = photoReference {
            print("✅ GooglePlaces: Photo reference obtained: \(photoRef.prefix(20))...")
        } else {
            print("⚠️ GooglePlaces: No photos available for this place")
        }

        return PlaceDetails(
            placeId: firstResult.placeId,
            name: firstResult.name,
            photoReference: photoReference
        )
    }

    /// Get the photo URL for a place
    func getPhotoURL(photoReference: String, maxWidth: Int = 400) -> String {
        let photoURL = "\(baseURL)/photo?maxwidth=\(maxWidth)&photo_reference=\(photoReference)&key=\(apiKey)"
        print("🖼️ GooglePlaces: Generated photo URL: \(photoURL.replacingOccurrences(of: apiKey, with: "***API_KEY***"))")
        return photoURL
    }

    /// Fetch place details and photo URL in one call
    func fetchPlacePhoto(name: String, coordinate: CLLocationCoordinate2D) async throws -> String? {
        print("🚀 GooglePlaces: Starting photo fetch for '\(name)'")

        guard let placeDetails = try await findPlace(name: name, coordinate: coordinate) else {
            print("⚠️ GooglePlaces: No place details found")
            return nil
        }

        guard let photoReference = placeDetails.photoReference else {
            print("⚠️ GooglePlaces: Place found but no photo reference available")
            return nil
        }

        let photoURL = getPhotoURL(photoReference: photoReference)
        print("✅ GooglePlaces: Photo URL ready to use")
        return photoURL
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
