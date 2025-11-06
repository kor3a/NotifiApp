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

        let db = Firestore.firestore()

        // Query to find user by email since we store documents by username
        db.collection("users")
            .whereField("email", isEqualTo: currentUserEmail)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }

                DispatchQueue.main.async {
                    self.isLoading = false

                    if let error = error {
                        self.errorMessage = "Error fetching user: \(error.localizedDescription)"
                        return
                    }

                    guard let document = snapshot?.documents.first,
                          let userData = document.data() as? [String: Any] else {
                        self.errorMessage = "User data not found"
                        return
                    }

                    self.user = User(
                        userId: userData["userId"] as? String ?? "",
                        name: userData["name"] as? String ?? "",
                        email: userData["email"] as? String ?? "",
                        joined: userData["joined"] as? TimeInterval ?? 0
                    )
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
