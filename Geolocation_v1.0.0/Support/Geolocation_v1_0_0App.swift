//
//  Geolocation_v1_0_0App.swift
//  Geolocation_v1.0.0
//
//  Created by Subong Jeon on 8/2/24.
//

import SwiftUI
import FirebaseCore

@main
struct Geolocation_v1_0_0App: App {

    init() {
        FirebaseApp.configure()

        // Initialize LocationMonitoringManager so it's ready to handle background location events
        // This ensures the app can respond to geofence events even when launched in the background
        _ = LocationMonitoringManager.shared
        #if DEBUG
        print("🚀 App: LocationMonitoringManager initialized for background location support")
        #endif
    }

    var body: some Scene {
        WindowGroup {
            MainView()
        }
    }
}
