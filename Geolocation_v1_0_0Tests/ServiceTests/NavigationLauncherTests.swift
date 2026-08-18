//
//  NavigationLauncherTests.swift
//  Geolocation_v1_0_0Tests
//

import XCTest
import CoreLocation
@testable import Allim

final class NavigationLauncherTests: XCTestCase {

    private let store = NavigationDestination(name: "Trader Joe's", latitude: 37.3318, longitude: -122.0312)
    private let nameOnly = NavigationDestination(name: "Trader Joe's")

    // MARK: - Apple Maps

    func testAppleMapsURL_usesCoordinateAndDrivingMode() {
        let url = NavigationLauncher.directionsURL(for: store, in: .appleMaps)
        XCTAssertEqual(url?.absoluteString, "https://maps.apple.com/?daddr=37.3318,-122.0312&dirflg=d")
    }

    func testAppleMapsURL_fallsBackToEncodedName() {
        let url = NavigationLauncher.directionsURL(for: nameOnly, in: .appleMaps)
        XCTAssertEqual(url?.absoluteString, "https://maps.apple.com/?daddr=Trader%20Joe's&dirflg=d")
    }

    // MARK: - Google Maps

    func testGoogleMapsURL_usesAppSchemeAndDrivingMode() {
        let url = NavigationLauncher.directionsURL(for: store, in: .googleMaps)
        XCTAssertEqual(url?.scheme, "comgooglemaps")
        XCTAssertEqual(url?.absoluteString, "comgooglemaps://?daddr=37.3318,-122.0312&directionsmode=driving")
    }

    func testGoogleMapsURL_fallsBackToEncodedName() {
        let url = NavigationLauncher.directionsURL(for: nameOnly, in: .googleMaps)
        XCTAssertEqual(url?.absoluteString, "comgooglemaps://?daddr=Trader%20Joe's&directionsmode=driving")
    }

    // MARK: - Waze

    func testWazeURL_navigatesImmediately() {
        let url = NavigationLauncher.directionsURL(for: store, in: .waze)
        XCTAssertEqual(url?.absoluteString, "waze://?ll=37.3318,-122.0312&navigate=yes")
    }

    // MARK: - Destination

    func testDestination_rejectsInvalidCoordinate() {
        let bogus = NavigationDestination(name: "Nowhere", latitude: 999, longitude: 999)
        XCTAssertNil(bogus.coordinate)
    }

    func testDestination_isNilWhenOnlyOneComponentIsPresent() {
        let halfCoordinate = NavigationDestination(name: "Half", latitude: 37.3318, longitude: nil)
        XCTAssertNil(halfCoordinate.coordinate)
    }

    func testDestination_withoutCoordinateStillProducesAURL() {
        let blankName = NavigationDestination(name: "   ")
        XCTAssertNil(NavigationLauncher.directionsURL(for: blankName, in: .appleMaps))
    }

    // MARK: - Notification Payload

    func testNavigationDestination_readsDoublesFromLocalNotification() {
        let destination = NotificationManager.navigationDestination(from: [
            "storeName": "Costco",
            "storeLatitude": 37.3318,
            "storeLongitude": -122.0312
        ])

        XCTAssertEqual(destination.name, "Costco")
        XCTAssertEqual(destination.coordinate?.latitude ?? 0, 37.3318, accuracy: 0.00001)
        XCTAssertEqual(destination.coordinate?.longitude ?? 0, -122.0312, accuracy: 0.00001)
    }

    func testNavigationDestination_readsStringsFromRemotePayload() {
        let destination = NotificationManager.navigationDestination(from: [
            "storeName": "Costco",
            "storeLatitude": "37.3318",
            "storeLongitude": "-122.0312"
        ])

        XCTAssertEqual(destination.coordinate?.latitude ?? 0, 37.3318, accuracy: 0.00001)
    }

    func testNavigationDestination_survivesAMissingCoordinate() {
        let destination = NotificationManager.navigationDestination(from: ["storeName": "Costco"])

        XCTAssertEqual(destination.name, "Costco")
        XCTAssertNil(destination.coordinate)
    }

    func testNavigationDestination_fallsBackWhenStoreNameIsBlank() {
        let destination = NotificationManager.navigationDestination(from: ["storeName": "   "])
        XCTAssertEqual(destination.name, "Store")
    }
}
