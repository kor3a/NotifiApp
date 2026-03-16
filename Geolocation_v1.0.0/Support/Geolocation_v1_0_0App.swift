//
//  Geolocation_v1_0_0App.swift
//  Geolocation_v1.0.0
//
//  Created by Subong Jeon on 8/2/24.
//

import SwiftUI
import FirebaseCore
import WidgetKit
import UIKit
import GoogleMobileAds

@main
struct Geolocation_v1_0_0App: App {

    @Environment(\.scenePhase) private var scenePhase

    init() {
        FirebaseApp.configure()

        // Initialize Google Mobile Ads SDK
        MobileAds.shared.start(completionHandler: nil)

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
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                // Reload widget timelines every time the app becomes active (launch or foreground)
                // so the widget reflects the latest store data sorted by reminder count.
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
    }
}
