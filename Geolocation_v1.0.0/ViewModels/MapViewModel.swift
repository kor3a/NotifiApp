//
//  MapViewModel.swift
//  Geolocation_v1.0.0
//
//  Created by Subong Jeon on 9/10/24.
//

import Foundation
import MapKit

class MapViewModel: NSObject, ObservableObject, MKMapViewDelegate, CLLocationManagerDelegate {
    @Published var region = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 37.331516, longitude: -121.891054), latitudinalMeters: 5000, longitudinalMeters: 5000)
    
    @Published var location:CLLocationCoordinate2D = .init(latitude: 34.1304575, longitude: -117.6344637)
    @Published var isLocationAuthorized:Bool = false
    @Published var manager:CLLocationManager = .init()
    
    /// delete this later. Won't need this
    var locationManager: CLLocationManager?
    
    override init() {
        super.init()
        
        manager.delegate = self
        manager.requestWhenInUseAuthorization()
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let currentLocation = locations.last else{return}
            
        location = .init(latitude: currentLocation.coordinate.latitude, longitude: currentLocation.coordinate.longitude)
        region = .init(center: location, latitudinalMeters: 5000, longitudinalMeters: 5000)
        isLocationAuthorized = true
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
        checkLocationAuthorization()
        print(error.localizedDescription)
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        checkLocationAuthorization()
    }
    
    private func checkLocationAuthorization() {
        
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .restricted:
            print("Your location is restricted likely due to parental controls.")
            isLocationAuthorized = false
        case .denied:
            print("You have denied this app location permission. Go into settings to change it.")
            isLocationAuthorized = false
        case .authorizedAlways, .authorizedWhenInUse:
            manager.requestLocation()
            isLocationAuthorized = true
        @unknown default:
            break
        }
    }
}
