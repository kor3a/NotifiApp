//
//  AppDelegate.swift
//  Geolocation_v1.0.0
//
//  Wires up APNs ↔ FCM so the app can receive push notifications when closed.
//  The SwiftUI entry point adopts this via @UIApplicationDelegateAdaptor.
//
//  UNUserNotificationCenter delegate is owned by NotificationManager (which
//  already handles willPresent and didReceive). AppDelegate only manages
//  the APNs ↔ FCM token bridge.
//

import UIKit
import FirebaseMessaging

class AppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Register for remote (APNs) notifications so iOS can hand us an APNs
        // device token, which Firebase Messaging maps to an FCM token.
        application.registerForRemoteNotifications()
        Messaging.messaging().delegate = self
        return true
    }

    // APNs successfully registered – give the token to Firebase Messaging.
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Messaging.messaging().apnsToken = deviceToken
        #if DEBUG
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        print("AppDelegate: APNs token registered: \(tokenString)")
        #endif
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        #if DEBUG
        print("AppDelegate: ❌ Failed to register for remote notifications: \(error.localizedDescription)")
        #endif
    }
}

// MARK: - MessagingDelegate

extension AppDelegate: MessagingDelegate {
    /// Called whenever FCM issues a new registration token for this device.
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken = fcmToken else { return }
        #if DEBUG
        print("AppDelegate: FCM token refreshed: \(fcmToken)")
        #endif

        // Save immediately if the user session is already loaded.
        let sessionManager = UserSessionManager.shared
        if let userId = sessionManager.currentUser?.userId {
            FCMTokenService.shared.saveToken(fcmToken, for: userId)
        } else {
            // Session not yet loaded – store locally; HomeView saves it on load.
            UserDefaults.standard.set(fcmToken, forKey: "pendingFCMToken")
        }
    }
}
