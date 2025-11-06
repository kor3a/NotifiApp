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

class ProfileViewModel: ObservableObject {

    init() {
        fetchUser()
    }

    @Published var user: User? = nil
    @Published var isLoading: Bool = true
    @Published var errorMessage: String = ""

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
                        joined: userData["joined"] as? TimeInterval ?? 0
                    )
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
}
