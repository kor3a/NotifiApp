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

    init() {
        fetchUser()
    }

    @Published var user: User? = nil
    @Published var isLoading: Bool = true
    @Published var errorMessage: String = ""
    @Published var successMessage: String = ""

    // Fields for editing
    @Published var newName: String = ""
    @Published var newPassword: String = ""
    @Published var confirmPassword: String = ""

    func fetchUser() {
        // Get the current authenticated user's email
        guard let currentUserEmail = Auth.auth().currentUser?.email else {
            DispatchQueue.main.async {
                self.errorMessage = "No authenticated user found"
                self.isLoading = false
            }
            return
        }

        print("ProfileViewModel: Fetching user with email: \(currentUserEmail)")
        let db = Firestore.firestore()

        // Query to find user by email since we store documents by username
        db.collection("users")
            .whereField("email", isEqualTo: currentUserEmail)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }

                if let error = error {
                    print("ProfileViewModel: Error fetching user: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        self.isLoading = false
                        self.errorMessage = "Error fetching user: \(error.localizedDescription)"
                    }
                    return
                }

                print("ProfileViewModel: Query returned \(snapshot?.documents.count ?? 0) documents")

                guard let document = snapshot?.documents.first else {
                    print("ProfileViewModel: No documents found for email: \(currentUserEmail)")
                    // Try to fetch all users to debug
                    self.debugFetchAllUsers(email: currentUserEmail)
                    return
                }

                let userData = document.data()
                print("ProfileViewModel: Found user data: \(userData)")

                DispatchQueue.main.async {
                    self.isLoading = false
                    self.user = User(
                        userId: userData["userId"] as? String ?? "",
                        name: userData["name"] as? String ?? "",
                        email: userData["email"] as? String ?? "",
                        joined: userData["joined"] as? TimeInterval ?? 0,
                        profilePictureURL: userData["profilePictureURL"] as? String
                    )
                    self.newName = self.user?.name ?? ""
                }
            }
    }

    private func debugFetchAllUsers(email: String) {
        let db = Firestore.firestore()
        db.collection("users").getDocuments { [weak self] snapshot, error in
            if let error = error {
                print("ProfileViewModel: Error fetching all users for debug: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self?.isLoading = false
                    self?.errorMessage = "User data not found. Please ensure your profile was created during signup."
                }
                return
            }

            print("ProfileViewModel: Total users in collection: \(snapshot?.documents.count ?? 0)")
            snapshot?.documents.forEach { doc in
                print("ProfileViewModel: User document ID: \(doc.documentID), data: \(doc.data())")
            }

            DispatchQueue.main.async {
                self?.isLoading = false
                self?.errorMessage = "User data not found in Firestore. Your account may not have completed signup. Please try signing up again."
            }
        }
    }
    
    func signOut() {
        do {
            try Auth.auth().signOut()
        } catch {
            print("Could not sign out")
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

        print("=== IMAGE PROCESSING ===")
        print("Image size: \(image.size)")
        print("Image scale: \(image.scale)")

        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            print("Failed to convert image to JPEG data")
            DispatchQueue.main.async {
                self.errorMessage = "Failed to process image"
            }
            return
        }

        print("JPEG data size: \(imageData.count) bytes")
        print("User ID: \(userId)")

        // Test Firebase Storage configuration
        print("=== STORAGE CONFIGURATION ===")

        // Try with explicit bucket URL
        let storageRef = Storage.storage().reference(forURL: "gs://georeminder-pilot.appspot.com")

        print("Storage reference created for bucket: \(storageRef.bucket)")
        print("Storage full path: \(storageRef.fullPath)")
        print("================================")

        let profilePicRef = storageRef.child("profile_pictures/\(userId).jpg")

        // Create metadata for the upload
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        DispatchQueue.main.async {
            self.isLoading = true
        }

        print("=== STARTING UPLOAD ===")
        print("Storage reference: \(storageRef)")
        print("Profile pic reference: \(profilePicRef)")
        print("Full path: \(profilePicRef.fullPath)")
        print("Bucket: \(profilePicRef.bucket)")
        print("========================")

        profilePicRef.putData(imageData, metadata: metadata) { [weak self] uploadMetadata, error in
            guard let self = self else { return }

            if let error = error {
                print("=== UPLOAD ERROR DETAILS ===")
                print("Error domain: \((error as NSError).domain)")
                print("Error code: \((error as NSError).code)")
                print("Error description: \(error.localizedDescription)")
                print("Full error: \(error)")
                print("Storage path: profile_pictures/\(userId).jpg")
                print("Auth user: \(Auth.auth().currentUser?.uid ?? "nil")")
                print("===========================")
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.errorMessage = "Failed to upload profile picture: \(error.localizedDescription)"
                }
                return
            }

            print("=== UPLOAD SUCCESS ===")
            print("Upload metadata: \(String(describing: uploadMetadata))")
            print("========================")

            // Get download URL
            profilePicRef.downloadURL { url, error in
                if let error = error {
                    print("Error getting download URL: \(error.localizedDescription)")
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
        guard let userId = user?.userId else {
            DispatchQueue.main.async {
                self.isLoading = false
                self.errorMessage = "User ID not found"
            }
            return
        }

        let db = Firestore.firestore()
        db.collection("users").document(userId).updateData([
            "profilePictureURL": url
        ]) { [weak self] error in
            guard let self = self else { return }

            DispatchQueue.main.async {
                self.isLoading = false
                if let error = error {
                    self.errorMessage = "Failed to update profile picture: \(error.localizedDescription)"
                } else {
                    self.user?.profilePictureURL = url
                    self.successMessage = "Profile picture updated successfully!"
                    // Clear success message after 3 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        self.successMessage = ""
                    }
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
        guard let userId = user?.userId else {
            DispatchQueue.main.async {
                self.errorMessage = "User ID not found"
                self.isLoading = false
            }
            completion(false)
            return
        }

        let db = Firestore.firestore()
        db.collection("users").document(userId).updateData([
            "name": newName
        ]) { [weak self] error in
            guard let self = self else { return }

            if let error = error {
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to update name: \(error.localizedDescription)"
                    self.isLoading = false
                }
                completion(false)
            } else {
                DispatchQueue.main.async {
                    self.user?.name = self.newName
                }
                completion(true)
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
