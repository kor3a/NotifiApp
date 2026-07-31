//
//  ProfileViewModel.swift
//  Geolocation_v1.0.0
//
//  Created by James Jeon on 10/13/24.
//

import Foundation
import Firebase
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import UIKit

class ProfileViewModel: ObservableObject {
    // Reference to shared user session
    private let sessionManager = UserSessionManager.shared

    init() {
        // Don't initialize newName here to avoid keyboard conflicts
        // It will be set in the view's onAppear
    }

    @Published var isLoading: Bool = false
    @Published var errorMessage: String = ""
    @Published var successMessage: String = ""
    @Published var needsReauthForDeletion: Bool = false

    // Fields for editing
    @Published var newName: String = ""
    @Published var newPassword: String = ""
    @Published var confirmPassword: String = ""

    // Computed property to access current user
    var user: User? {
        return sessionManager.currentUser
    }
    
    func signOut() {
        // Backgrounds are stored per device, so clear them here — the next
        // account to sign in on this device starts from the default look.
        BackgroundPreferences.shared.resetAll()

        // Remove this device's push token from the user's document first —
        // rules only allow updating your own doc, so it must happen while
        // still authenticated. Times out internally so sign-out never hangs;
        // FCMTokenManager's auth observer then invalidates the device token
        // itself once the sign-out lands.
        FCMTokenManager.shared.clearTokenForCurrentUser {
            // Perform sign out asynchronously to avoid blocking the main thread
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try Auth.auth().signOut()
                    // MainViewModel's auth listener will handle clearing the session
                } catch {
                    #if DEBUG
                    print("Could not sign out: \(error.localizedDescription)")
                    #endif
                }
            }
        }
    }

    /// How this account confirms its identity before deletion. Drives which prompt
    /// ProfileView shows — a password field, or the Apple/Google sheet.
    var reauthMethod: AuthenticationManager.ReauthMethod {
        sessionManager.reauthMethod
    }

    /// Apple/Google accounts have no password, so the change-password form is
    /// hidden for them rather than failing when they submit it.
    var canChangePassword: Bool {
        sessionManager.hasPasswordProvider
    }

    func deleteAccount() {
        let method = reauthMethod

        // Apple requires the sign-in token to be revoked when an account is deleted,
        // and the authorization code that revokes it only comes from a fresh Apple
        // authorization — so Apple accounts always re-authenticate up front rather
        // than waiting for Firebase to ask.
        if method == .apple {
            reauthenticateAndDelete(using: .apple)
            return
        }

        isLoading = true
        errorMessage = ""
        sessionManager.deleteAccount { [weak self] success, errorMsg in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.isLoading = false
                // On success the auth listener signs the user out automatically
                guard !success else { return }

                guard errorMsg == UserSessionManager.requiresRecentLoginMessage else {
                    self.errorMessage = errorMsg ?? "Failed to delete account"
                    return
                }

                switch method {
                case .password:
                    self.needsReauthForDeletion = true
                case .google, .apple:
                    // No password to ask for — re-confirm through the provider.
                    self.reauthenticateAndDelete(using: method)
                }
            }
        }
    }

    /// Re-authenticate through Apple/Google, then delete. Cancelling the provider
    /// sheet simply returns the user to the profile with no error.
    func reauthenticateAndDelete(using method: AuthenticationManager.ReauthMethod) {
        isLoading = true
        errorMessage = ""
        sessionManager.reauthenticateAndDeleteAccount(using: method) { [weak self] success, cancelled, errorMsg in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.isLoading = false
                if !success && !cancelled {
                    self.errorMessage = errorMsg ?? "Failed to delete account"
                }
                // On success the auth listener signs the user out automatically
            }
        }
    }

    func reauthenticateAndDelete(password: String) {
        isLoading = true
        errorMessage = ""
        sessionManager.reauthenticateAndDeleteAccount(password: password) { [weak self] success, errorMsg in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.isLoading = false
                if !success {
                    self.errorMessage = errorMsg ?? "Failed to delete account"
                }
                // On success the auth listener signs the user out automatically
            }
        }
    }

    // Upload profile picture to Firebase Storage
    func uploadProfilePicture(image: UIImage) {
        guard let userId = user?.userId else {
            DispatchQueue.main.async {
                self.errorMessage = "User ID not found"
            }
            return
        }

        #if DEBUG
        print("=== IMAGE PROCESSING ===")
        print("Image size: \(image.size)")
        print("Image scale: \(image.scale)")
        #endif

        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            #if DEBUG
            print("Failed to convert image to JPEG data")
            #endif
            DispatchQueue.main.async {
                self.errorMessage = "Failed to process image"
            }
            return
        }

        #if DEBUG
        print("JPEG data size: \(imageData.count) bytes")
        print("User ID: \(userId)")
        #endif

        // Create Storage reference (uses bucket from GoogleService-Info.plist)
        let storageRef = Storage.storage().reference()
        let profilePicRef = storageRef.child("profile_pictures/\(userId).jpg")

        #if DEBUG
        print("=== STORAGE CONFIGURATION ===")
        print("Storage bucket: \(profilePicRef.bucket)")
        print("Storage path: \(profilePicRef.fullPath)")
        print("================================")
        #endif

        // Create metadata for the upload
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        DispatchQueue.main.async {
            self.isLoading = true
        }

        #if DEBUG
        print("Starting upload...")
        #endif

        profilePicRef.putData(imageData, metadata: metadata) { [weak self] uploadMetadata, error in
            guard let self = self else { return }

            if let error = error {
                #if DEBUG
                print("=== UPLOAD ERROR DETAILS ===")
                print("Error domain: \((error as NSError).domain)")
                print("Error code: \((error as NSError).code)")
                print("Error description: \(error.localizedDescription)")
                print("Full error: \(error)")
                print("Storage path: profile_pictures/\(userId).jpg")
                print("Auth user: \(Auth.auth().currentUser?.uid ?? "nil")")
                print("===========================")
                #endif
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.errorMessage = "Failed to upload profile picture: \(error.localizedDescription)"
                }
                return
            }

            #if DEBUG
            print("=== UPLOAD SUCCESS ===")
            print("Upload metadata: \(String(describing: uploadMetadata))")
            print("========================")
            #endif

            // Get download URL
            profilePicRef.downloadURL { url, error in
                if let error = error {
                    #if DEBUG
                    print("Error getting download URL: \(error.localizedDescription)")
                    #endif
                    DispatchQueue.main.async {
                        self.isLoading = false
                        self.errorMessage = "Failed to get image URL: \(error.localizedDescription)"
                    }
                    return
                }

                guard let downloadURL = url?.absoluteString else {
                    DispatchQueue.main.async {
                        self.isLoading = false
                        self.errorMessage = "Failed to get image URL"
                    }
                    return
                }

                // Update Firestore with the profile picture URL
                self.updateProfilePictureURL(downloadURL)
            }
        }
    }

    private func updateProfilePictureURL(_ url: String) {
        DispatchQueue.main.async {
            self.isLoading = true
        }

        sessionManager.updateProfilePictureURL(url) { [weak self] success, errorMsg in
            guard let self = self else { return }

            DispatchQueue.main.async {
                self.isLoading = false
                if success {
                    self.successMessage = "Profile picture updated successfully!"
                    // Clear success message after 3 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        self.successMessage = ""
                    }
                } else {
                    self.errorMessage = errorMsg ?? "Failed to update profile picture"
                }
            }
        }
    }

    // Save profile changes (name and/or password)
    func saveProfileChanges() {
        errorMessage = ""
        successMessage = ""

        // Validate inputs
        if newName.trimmingCharacters(in: .whitespaces).isEmpty {
            errorMessage = "Name cannot be empty"
            return
        }

        // Check password validation if user is trying to change password
        if !newPassword.isEmpty || !confirmPassword.isEmpty {
            guard canChangePassword else {
                errorMessage = "Your account signs in with Apple or Google, so it has no password to change."
                return
            }
            if newPassword != confirmPassword {
                errorMessage = "Passwords do not match"
                return
            }
            if newPassword.count < 6 {
                errorMessage = "Password must be at least 6 characters"
                return
            }
        }

        isLoading = true

        // Update name in Firestore
        updateName { [weak self] success in
            guard let self = self else { return }

            if !success {
                return // Error message already set
            }

            // Update password if provided
            if !self.newPassword.isEmpty {
                self.updatePassword { passwordSuccess in
                    DispatchQueue.main.async {
                        self.isLoading = false
                        if passwordSuccess {
                            self.successMessage = "Profile updated successfully!"
                            self.newPassword = ""
                            self.confirmPassword = ""
                        }
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.successMessage = "Profile updated successfully!"
                }
            }

            // Clear success message after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                self.successMessage = ""
            }
        }
    }

    private func updateName(completion: @escaping (Bool) -> Void) {
        sessionManager.updateUserName(newName) { [weak self] success, errorMsg in
            guard let self = self else { return }

            if success {
                completion(true)
            } else {
                DispatchQueue.main.async {
                    self.errorMessage = errorMsg ?? "Failed to update name"
                    self.isLoading = false
                }
                completion(false)
            }
        }
    }

    private func updatePassword(completion: @escaping (Bool) -> Void) {
        guard let currentUser = Auth.auth().currentUser else {
            DispatchQueue.main.async {
                self.errorMessage = "No authenticated user found"
                self.isLoading = false
            }
            completion(false)
            return
        }

        currentUser.updatePassword(to: newPassword) { [weak self] error in
            guard let self = self else { return }

            if let error = error {
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to update password: \(error.localizedDescription)"
                }
                completion(false)
            } else {
                completion(true)
            }
        }
    }
}
