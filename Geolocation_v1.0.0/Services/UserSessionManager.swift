//
//  UserSessionManager.swift
//  Geolocation_v1.0.0
//
//  Created on 11/10/24.
//

import Foundation
import Firebase
import FirebaseAuth
import FirebaseFirestore
import Combine

class UserSessionManager: ObservableObject {
    static let shared = UserSessionManager()

    @Published var currentUser: User? = nil
    @Published var isLoading: Bool = false
    @Published var errorMessage: String = ""

    private init() {
        // Private initializer for singleton
    }

    // Fetch user data from Firestore
    func fetchUser() {
        // Get the current authenticated user's email
        guard let currentUserEmail = Auth.auth().currentUser?.email else {
            DispatchQueue.main.async {
                self.errorMessage = "No authenticated user found"
                self.isLoading = false
            }
            return
        }

        print("UserSessionManager: Fetching user with email: \(currentUserEmail)")
        isLoading = true
        let db = Firestore.firestore()

        // Query to find user by email since we store documents by username
        db.collection("users")
            .whereField("email", isEqualTo: currentUserEmail)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }

                if let error = error {
                    print("UserSessionManager: Error fetching user: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        self.isLoading = false
                        self.errorMessage = "Error fetching user: \(error.localizedDescription)"
                    }
                    return
                }

                print("UserSessionManager: Query returned \(snapshot?.documents.count ?? 0) documents")

                guard let document = snapshot?.documents.first else {
                    print("UserSessionManager: No documents found for email: \(currentUserEmail)")
                    // Try to fetch all users to debug
                    self.debugFetchAllUsers(email: currentUserEmail)
                    return
                }

                let userData = document.data()
                print("UserSessionManager: Found user data: \(userData)")

                DispatchQueue.main.async {
                    self.isLoading = false
                    self.currentUser = User(
                        userId: userData["userId"] as? String ?? "",
                        name: userData["name"] as? String ?? "",
                        email: userData["email"] as? String ?? "",
                        joined: userData["joined"] as? TimeInterval ?? 0,
                        profilePictureURL: userData["profilePictureURL"] as? String
                    )
                }
            }
    }

    private func debugFetchAllUsers(email: String) {
        let db = Firestore.firestore()
        db.collection("users").getDocuments { [weak self] snapshot, error in
            if let error = error {
                print("UserSessionManager: Error fetching all users for debug: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self?.isLoading = false
                    self?.errorMessage = "User data not found. Please ensure your profile was created during signup."
                }
                return
            }

            print("UserSessionManager: Total users in collection: \(snapshot?.documents.count ?? 0)")
            snapshot?.documents.forEach { doc in
                print("UserSessionManager: User document ID: \(doc.documentID), data: \(doc.data())")
            }

            DispatchQueue.main.async {
                self?.isLoading = false
                self?.errorMessage = "User data not found in Firestore. Your account may not have completed signup. Please try signing up again."
            }
        }
    }

    // Update user name in Firestore and local cache
    func updateUserName(_ newName: String, completion: @escaping (Bool, String?) -> Void) {
        guard let userId = currentUser?.userId else {
            completion(false, "User ID not found")
            return
        }

        let db = Firestore.firestore()
        db.collection("users").document(userId).updateData([
            "name": newName
        ]) { [weak self] error in
            guard let self = self else { return }

            if let error = error {
                completion(false, "Failed to update name: \(error.localizedDescription)")
            } else {
                DispatchQueue.main.async {
                    self.currentUser?.name = newName
                }
                completion(true, nil)
            }
        }
    }

    // Update profile picture URL in Firestore and local cache
    func updateProfilePictureURL(_ url: String, completion: @escaping (Bool, String?) -> Void) {
        guard let userId = currentUser?.userId else {
            completion(false, "User ID not found")
            return
        }

        let db = Firestore.firestore()
        db.collection("users").document(userId).updateData([
            "profilePictureURL": url
        ]) { [weak self] error in
            guard let self = self else { return }

            if let error = error {
                completion(false, "Failed to update profile picture: \(error.localizedDescription)")
            } else {
                DispatchQueue.main.async {
                    self.currentUser?.profilePictureURL = url
                }
                completion(true, nil)
            }
        }
    }

    // Clear user session (call on logout)
    func clearSession() {
        // Only clear if there's actually a session to clear (prevents redundant updates)
        guard currentUser != nil || !errorMessage.isEmpty || isLoading else {
            return
        }

        DispatchQueue.main.async {
            self.currentUser = nil
            self.errorMessage = ""
            self.isLoading = false
        }
    }
}
