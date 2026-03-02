//
//  Geolocation_v1_0_0App.swift
//  Geolocation_v1.0.0
//
//  Created by Subong Jeon on 8/2/24.
//

import SwiftUI
import FirebaseCore
import GoogleMobileAds
import WidgetKit

@main
struct Geolocation_v1_0_0App: App {

    init() {
        FirebaseApp.configure()

        if AdConfiguration.areAdsEnabled {
            MobileAds.shared.start(completionHandler: nil)
        } else {
            #if DEBUG
            print("📣 AdMob disabled: Add valid app and banner IDs in Info.plist/Secrets.xcconfig")
            #endif
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

enum AdConfiguration {
    static let testBannerAdUnitID = "ca-app-pub-3940256099942544/2435281174"
    static let testInterstitialAdUnitID = "ca-app-pub-3940256099942544/4411468910"

    static var applicationID: String {
        return configuredValue(for: "GADApplicationIdentifier") ?? ""
    }

    static var bannerAdUnitID: String {
        #if DEBUG
        return configuredValue(for: "ADMOB_BANNER_AD_UNIT_ID") ?? testBannerAdUnitID
        #else
        return configuredValue(for: "ADMOB_BANNER_AD_UNIT_ID") ?? ""
        #endif
    }

    static var interstitialAdUnitID: String {
        #if DEBUG
        return configuredValue(for: "ADMOB_INTERSTITIAL_AD_UNIT_ID") ?? testInterstitialAdUnitID
        #else
        return configuredValue(for: "ADMOB_INTERSTITIAL_AD_UNIT_ID") ?? ""
        #endif
    }

    static var areAdsEnabled: Bool {
        isValidApplicationID(applicationID) && isValidAdUnitID(bannerAdUnitID)
    }

    private static func configuredValue(for key: String) -> String? {
        guard let rawValue = Bundle.main.object(forInfoDictionaryKey: key) as? String else {
            return nil
        }
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, !value.contains("$(") else {
            return nil
        }
        return value
    }

    private static func isValidApplicationID(_ id: String) -> Bool {
        id.hasPrefix("ca-app-pub-") && id.contains("~")
    }

    private static func isValidAdUnitID(_ id: String) -> Bool {
        id.hasPrefix("ca-app-pub-") && id.contains("/")
    }
}
