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

@main
struct Geolocation_v1_0_0App: App {

    init() {
        FirebaseApp.configure()

        // Apply Special Elite font to all navigation bar titles
        if let specialEliteLarge = UIFont(name: "SpecialElite-Regular", size: 34),
           let specialEliteInline = UIFont(name: "SpecialElite-Regular", size: 17) {
            UINavigationBar.appearance().largeTitleTextAttributes = [.font: specialEliteLarge]
            UINavigationBar.appearance().titleTextAttributes = [.font: specialEliteInline]
        }

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
                .onAppear {
                    // Reload widget timelines every time the app comes to the foreground
                    // so the widget reflects the latest store data immediately on open.
                    WidgetCenter.shared.reloadAllTimelines()
                }
        }
    }
}
