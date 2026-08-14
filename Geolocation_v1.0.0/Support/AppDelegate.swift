//
//  AppDelegate.swift
//  Geolocation_v1.0.0
//
//  Bridges UIKit's UIApplicationDelegate to SwiftUI so that APNs device tokens
//  are forwarded to FirebaseMessaging.  Without this step Firebase cannot map
//  an APNs token to an FCM registration token, and background push notifications
//  will not be delivered.
//
//  IMPORTANT — one-time Xcode setup required
//  -----------------------------------------
//  1. Open the project in Xcode.
//  2. Select the "Geolocation_v1.0.0" target → General → Frameworks, Libraries,
//     and Embedded Content → click "+" → choose "FirebaseMessaging" from the
//     firebase-ios-sdk package that is already linked to this project.
//  3. Under Signing & Capabilities add "Push Notifications".
//  4. Under Signing & Capabilities add "Background Modes" and tick
//     "Remote notifications".
//  (Steps 3 & 4 can also be done by editing the .entitlements file and
//   Info.plist — see the changes committed alongside this file.)
//

import UIKit
import FirebaseMessaging

class AppDelegate: NSObject, UIApplicationDelegate {

    // MARK: - UIApplicationDelegate

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Register as the FCM delegate so we receive the registration token.
        // Note: UNUserNotificationCenter.delegate is already set by NotificationManager.shared,
        // so we intentionally leave it alone here.
        Messaging.messaging().delegate = self

        // Keep the FCM token bound to the signed-in account: re-write it on
        // sign-in (account switches reuse the same token) and invalidate it on
        // sign-out so pushes for the previous account can't reach this device.
        FCMTokenManager.shared.startObservingAuthChanges()

        // Ask the OS for a remote-notification device token.  The result arrives
        // in didRegisterForRemoteNotificationsWithDeviceToken below.
        application.registerForRemoteNotifications()

        // Activate the Apple Watch link here rather than in the SwiftUI scene:
        // a message from the watch can background-launch this app, and it only
        // reaches us if the WCSession delegate is already set when it arrives.
        WatchConnectivityManager.shared.activate()

        return true
    }

    // MARK: - APNs token → Firebase

    /// Forward the raw APNs device token to FirebaseMessaging so it can derive
    /// the FCM registration token from it.
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Messaging.messaging().apnsToken = deviceToken
        #if DEBUG
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        print("✅ AppDelegate: APNs token registered — \(tokenString.prefix(16))…")
        #endif
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        #if DEBUG
        print("❌ AppDelegate: Failed to register for remote notifications: \(error.localizedDescription)")
        #endif
    }
}

// MARK: - MessagingDelegate

extension AppDelegate: MessagingDelegate {

    /// Called whenever Firebase issues a new or refreshed FCM registration token.
    /// We persist it to Firestore so Cloud Functions can address push notifications
    /// to this device.
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken else { return }
        #if DEBUG
        print("🔑 AppDelegate: FCM token received — \(fcmToken.prefix(20))…")
        #endif
        FCMTokenManager.shared.saveFCMToken(fcmToken)
    }
}
