//
//  FCMTokenManager.swift
//  Geolocation_v1.0.0
//
//  Saves (and refreshes) the device's FCM registration token to the current
//  user's Firestore document under the `fcmToken` field.
//
//  Cloud Functions read this field to address push notifications to the device.
//  The token is written:
//    • On first app launch (via AppDelegate → MessagingDelegate)
//    • Whenever Firebase rotates the token (automatic, happens periodically)
//    • If auth state was not yet available when the token first arrived, the
//      write is retried once the user signs in.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

final class FCMTokenManager {

    static let shared = FCMTokenManager()

    private let db = Firestore.firestore()
    /// The last token we successfully wrote, used to skip redundant writes.
    private var persistedToken: String?
    private var authListenerHandle: AuthStateDidChangeListenerHandle?

    private init() {}

    // MARK: - Public API

    /// Called by AppDelegate whenever Firebase issues a registration token.
    func saveFCMToken(_ token: String) {
        guard token != persistedToken else { return }

        if let email = Auth.auth().currentUser?.email {
            writeToken(token, forEmail: email)
        } else {
            // Token arrived before login completes; retry once auth is ready.
            listenOnceForAuthThenSave(token: token)
        }
    }

    // MARK: - Firestore write

    private func writeToken(_ token: String, forEmail email: String) {
        db.collection("users")
            .whereField("email", isEqualTo: email)
            .limit(to: 1)
            .getDocuments { [weak self] snapshot, error in
                guard let self else { return }

                if let error {
                    #if DEBUG
                    print("❌ FCMTokenManager: Firestore query error — \(error.localizedDescription)")
                    #endif
                    return
                }

                guard let doc = snapshot?.documents.first else {
                    #if DEBUG
                    print("⚠️ FCMTokenManager: No user document found for \(email)")
                    #endif
                    return
                }

                doc.reference.updateData(["fcmToken": token]) { [weak self] error in
                    #if DEBUG
                    if let error {
                        print("❌ FCMTokenManager: Failed to save token — \(error.localizedDescription)")
                    } else {
                        print("✅ FCMTokenManager: Token saved for \(email)")
                        self?.persistedToken = token
                    }
                    #endif
                    if error == nil { self?.persistedToken = token }
                }
            }
    }

    // MARK: - Deferred write

    private func listenOnceForAuthThenSave(token: String) {
        // Remove any existing listener before adding a new one to avoid duplicates.
        if let handle = authListenerHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }

        authListenerHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self, let email = user?.email else { return }
            // We have a user now — remove the listener and write.
            if let handle = self.authListenerHandle {
                Auth.auth().removeStateDidChangeListener(handle)
                self.authListenerHandle = nil
            }
            self.writeToken(token, forEmail: email)
        }
    }
}
