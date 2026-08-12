//
//  FCMTokenManager.swift
//  Geolocation_v1.0.0
//
//  Saves (and refreshes) the device's FCM registration token to the current
//  user's Firestore document under the `fcmToken` field.
//
//  Cloud Functions read this field to address push notifications to the device.
//
//  AN FCM TOKEN IDENTIFIES A DEVICE, NOT A USER
//  --------------------------------------------
//  The same token stays valid across account switches on one phone, so without
//  cleanup every account that ever signs in on a device ends up storing that
//  device's token — and pushes addressed to a signed-out account get delivered
//  to whoever is signed in now. To keep exactly one owner per token:
//    • On sign-in the token is (re)written to the new account's document,
//      bypassing the "already persisted" guard — an account switch reuses the
//      same token string, so the guard alone would skip the write.
//    • On sign-out the device token is invalidated via Messaging.deleteToken(),
//      so pushes aimed at any account that still stores it bounce instead of
//      reaching the next user on this device. A fresh token is issued
//      automatically and saved for the next account that signs in.
//    • The graceful sign-out path also removes the token from the user's
//      document while still authenticated (rules only allow updating your own
//      doc) via clearTokenForCurrentUser.
//  Server-side, the dedupeFcmToken Cloud Function clears a newly written token
//  from any other user document that still holds it.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
import FirebaseMessaging

final class FCMTokenManager {

    static let shared = FCMTokenManager()

    private let db = Firestore.firestore()
    /// The last token we successfully wrote, used to skip redundant writes.
    private var persistedToken: String?
    private var authListenerHandle: AuthStateDidChangeListenerHandle?
    /// Set once a signed-in user has been observed, so the device token is
    /// invalidated only on real sign-outs — not on cold launches that start
    /// signed out (which would churn the token for no reason).
    private var hasSeenSignedInUser = false

    private init() {}

    // MARK: - Public API

    /// Install the permanent auth observer that keeps the token bound to the
    /// currently signed-in account. Call once at app launch (AppDelegate).
    func startObservingAuthChanges() {
        guard authListenerHandle == nil else { return }

        authListenerHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self else { return }

            if user?.email != nil {
                self.hasSeenSignedInUser = true
                // Account may have changed since the token was last written.
                // The token string itself doesn't change on an account switch,
                // so reset the guard and re-write it for this account.
                self.persistedToken = nil
                Messaging.messaging().token { [weak self] token, error in
                    if let token {
                        self?.saveFCMToken(token)
                    } else if let error {
                        #if DEBUG
                        print("⚠️ FCMTokenManager: Could not fetch token on sign-in — \(error.localizedDescription)")
                        #endif
                    }
                }
            } else if self.hasSeenSignedInUser {
                // Signed out: invalidate this device's token so pushes
                // addressed to any account that still stores it are rejected
                // by FCM instead of being shown to the next user who signs in
                // here. A replacement token arrives via MessagingDelegate and
                // is saved once someone signs in again.
                self.persistedToken = nil
                Messaging.messaging().deleteToken { error in
                    #if DEBUG
                    if let error {
                        print("⚠️ FCMTokenManager: Failed to invalidate token on sign-out — \(error.localizedDescription)")
                    } else {
                        print("✅ FCMTokenManager: Device token invalidated on sign-out")
                    }
                    #endif
                }
            }
        }
    }

    /// Called by AppDelegate whenever Firebase issues a registration token.
    func saveFCMToken(_ token: String) {
        guard token != persistedToken else { return }

        // No signed-in user yet (token arrived before login) — the auth
        // observer saves it once sign-in completes.
        guard let email = Auth.auth().currentUser?.email else { return }
        writeToken(token, forEmail: email)
    }

    /// Best-effort removal of the stored token from the current user's document.
    /// Must run BEFORE Auth.signOut() — the rules only allow a user to update
    /// their own document. Always calls `completion` (on the main queue), after
    /// the removal or after `timeout` seconds, so sign-out can never hang on a
    /// bad connection; the sign-out invalidation and the server-side cleanup
    /// cover the cases where this write doesn't land.
    func clearTokenForCurrentUser(timeout: TimeInterval = 3, completion: @escaping () -> Void) {
        persistedToken = nil

        guard let email = Auth.auth().currentUser?.email else {
            DispatchQueue.main.async { completion() }
            return
        }

        var completed = false
        let finishOnce = {
            DispatchQueue.main.async {
                guard !completed else { return }
                completed = true
                completion()
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout, execute: finishOnce)

        db.collection("users")
            .whereField("email", isEqualTo: email)
            .limit(to: 1)
            .getDocuments { snapshot, _ in
                guard let doc = snapshot?.documents.first else {
                    finishOnce()
                    return
                }
                doc.reference.updateData(["fcmToken": FieldValue.delete()]) { error in
                    #if DEBUG
                    if let error {
                        print("⚠️ FCMTokenManager: Failed to clear token for \(email) — \(error.localizedDescription)")
                    } else {
                        print("✅ FCMTokenManager: Token cleared for \(email)")
                    }
                    #endif
                    finishOnce()
                }
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
                    }
                    #endif
                    if error == nil { self?.persistedToken = token }
                }
            }
    }
}
