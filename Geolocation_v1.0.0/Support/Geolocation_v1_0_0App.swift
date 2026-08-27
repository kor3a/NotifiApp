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
import GoogleSignIn

@main
struct Geolocation_v1_0_0App: App {

    // Wire up UIKit's UIApplicationDelegate so APNs tokens reach FirebaseMessaging.
    // AppDelegate sets Messaging.messaging().delegate, which in turn calls
    // FCMTokenManager to persist the FCM token to Firestore.
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @Environment(\.scenePhase) private var scenePhase

    init() {
        FirebaseApp.configure()

        // The tab bar is built the first time MainView resolves, and the
        // appearance proxy only reaches bars created after it is set.
        OrganicPalette.applyTabBarFont()

        // Configure Google Sign-In with the OAuth client ID from GoogleService-Info.plist.
        if let clientID = FirebaseApp.app()?.options.clientID {
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        }

        // Initialize Google Mobile Ads SDK
        MobileAds.shared.start(completionHandler: nil)

        // Initialize LocationMonitoringManager so it's ready to handle background location events
        // This ensures the app can respond to geofence events even when launched in the background
        _ = LocationMonitoringManager.shared

        // Initialize SubscriptionManager early so StoreKit transaction listener is active from launch
        _ = SubscriptionManager.shared
        #if DEBUG
        print("🚀 App: LocationMonitoringManager initialized for background location support")
        #endif
    }

    var body: some Scene {
        WindowGroup {
            MainView()
                .onOpenURL { url in
                    // Let Google Sign-In claim its OAuth callback URL first;
                    // fall through to our own deep links otherwise.
                    if GIDSignIn.sharedInstance.handle(url) {
                        return
                    }
                    handleDeepLink(url)
                }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                // Reload widget timelines every time the app becomes active (launch or foreground)
                // so the widget reflects the latest store data sorted by reminder count.
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
    }

    /// Handle `allim://` deep links. Currently only `allim://login`, opened from
    /// the email-verification web page (nearbuyallim.com/verify) after the user
    /// confirms their email. Signup signs the user out, so MainView already shows
    /// LoginView — simply bringing the app to the foreground lands the user there.
    /// Posting the notification lets LoginView react (e.g. clear stale errors) if
    /// it observes it.
    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "allim" else { return }
        #if DEBUG
        print("🔗 App: opened via deep link \(url.absoluteString)")
        #endif
        if url.host == "login" {
            NotificationCenter.default.post(name: .allimOpenLogin, object: nil)
        }
    }
}

extension Notification.Name {
    /// Posted when the app is opened via `allim://login` (e.g. from the email
    /// verification page). LoginView can observe this to reset its state.
    static let allimOpenLogin = Notification.Name("allimOpenLogin")
}
