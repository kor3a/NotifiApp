//
//  FCMTokenService.swift
//  Geolocation_v1.0.0
//
//  Saves the device's FCM token to the current user's Firestore document so
//  Cloud Functions can look it up when sending push notifications.
//

import Foundation
import FirebaseFirestore
import FirebaseMessaging

class FCMTokenService {
    static let shared = FCMTokenService()
    private let db = Firestore.firestore()
    private init() {}

    /// Call this after the user's session is loaded (userId is known) and
    /// whenever FCM delivers a refreshed token.
    func saveToken(_ token: String, for userId: String) {
        db.collection("users").document(userId).updateData([
            "fcmToken": token
        ]) { error in
            #if DEBUG
            if let error = error {
                print("FCMTokenService: ❌ Failed to save FCM token: \(error.localizedDescription)")
            } else {
                print("FCMTokenService: ✅ Saved FCM token for user \(userId)")
            }
            #endif
        }
    }

    /// Fetch the current FCM token and save it, if a userId is available.
    func refreshAndSave(userId: String) {
        Messaging.messaging().token { [weak self] token, error in
            if let error = error {
                #if DEBUG
                print("FCMTokenService: ❌ Error fetching FCM token: \(error.localizedDescription)")
                #endif
                return
            }
            guard let token = token else { return }
            self?.saveToken(token, for: userId)
        }
    }
}
