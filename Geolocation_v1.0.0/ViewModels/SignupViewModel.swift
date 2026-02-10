//
//  SignupViewModel.swift
//  Geolocation_v1.0.0
//
//  Created by Subong Jeon on 8/5/24.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

class SignupViewModel: ObservableObject {
   
    @Published var userId: String = ""
    @Published var email: String = ""
    @Published var name: String = ""
    @Published var password: String = ""
    @Published var confirmPassword: String = ""
    @Published var errorMessage: String = ""
    
    private let db = Firestore.firestore()
    
    
    init() {}
    
    func register() {
        guard validate() else {
            return
        }

        // Normalize userId to lowercase for consistency
        let normalizedUserId = userId.lowercased()
        // Normalize email to lowercase (Firebase Auth stores emails in lowercase)
        let normalizedEmail = email.lowercased()

        // Create Firebase Auth user first
        Auth.auth().createUser(withEmail: normalizedEmail, password: self.password) { [weak self] authResult, error in
            guard let self = self else { return }

            if let error = error {
                self.errorMessage = "Error creating user: \(error.localizedDescription)"
                return
            }

            guard let user = authResult?.user else {
                self.errorMessage = "Failed to retrieve user ID"
                return
            }

            // Now as an authenticated user, check if username is available and create user document
            self.checkUsernameAvailability(for: normalizedUserId) { result in
                switch result {
                case .success(let isAvailable):
                    if !isAvailable {
                        // Username is taken - delete the auth user and show error
                        self.deleteAuthUser(user: user)
                        self.errorMessage = "Username is already taken. Please try again with a different username."
                        return
                    }

                    // Username is available, create user document
                    self.createUser(normalizedUserId: normalizedUserId, normalizedEmail: normalizedEmail, authUserId: user.uid)

                case .failure(let error):
                    // Error checking username - delete the auth user and show error
                    self.deleteAuthUser(user: user)
                    self.errorMessage = "Error checking username availability: \(error.localizedDescription)"
                }
            }
        }
    }
    
    /// Check if username is available
    private func checkUsernameAvailability(for userId: String, completion: @escaping (Result<Bool, Error>) -> Void) {
        guard !userId.isEmpty else {
            print("Username is empty after normalization")
            completion(.failure(NSError(domain: "SignupViewModel", code: 1, userInfo: [NSLocalizedDescriptionKey: "Username is empty"])))
            return
        }

        db.collection("users")
            .document(userId)
            .getDocument { (document, error) in
                if let error = error {
                    print("Error checking username: \(error.localizedDescription)")
                    completion(.failure(error))
                    return
                }

                // If no documents are found, username is available
                completion(.success(!document!.exists))
            }
    }
    
    /// Create a new User document in Firestore
    private func createUser(normalizedUserId: String, normalizedEmail: String, authUserId: String) {
        let newUser = User(userId: normalizedUserId, name: name, email: normalizedEmail, joined: Date().timeIntervalSince1970)
        let userData = newUser.asDict()

        print("SignupViewModel: Creating user document with ID: \(normalizedUserId)")
        print("SignupViewModel: User data to save: \(userData)")

        db.collection("users")
            .document(normalizedUserId)
            .setData(userData) { error in
                if let error = error {
                    print("SignupViewModel: Error saving user: \(error.localizedDescription)")
                    self.errorMessage = "Error saving user: \(error.localizedDescription)"
                    // If we fail to create the Firestore document, we should delete the auth user
                    if let currentUser = Auth.auth().currentUser {
                        self.deleteAuthUser(user: currentUser)
                    }
                } else {
                    print("SignupViewModel: User '\(normalizedUserId)' created successfully in Firestore")
                    print("SignupViewModel: Signup complete! User can now log in.")

                    // Directly populate UserSessionManager with the new user data.
                    // This fixes a race condition where the auth state change listener
                    // triggers fetchUser() before the Firestore document exists.
                    DispatchQueue.main.async {
                        UserSessionManager.shared.currentUser = newUser
                        UserSessionManager.shared.errorMessage = ""
                        UserSessionManager.shared.isLoading = false
                    }
                }
            }
    }

    /// Delete Firebase Auth user (called when signup fails after auth creation)
    private func deleteAuthUser(user: FirebaseAuth.User) {
        user.delete { error in
            if let error = error {
                print("Error deleting auth user: \(error.localizedDescription)")
            } else {
                print("Auth user deleted successfully after failed signup")
            }
        }
    }
    
    private func validate () -> Bool {
        errorMessage = ""
        
        guard !email.trimmingCharacters(in: .whitespaces).isEmpty,
              !password.trimmingCharacters(in: .whitespaces).isEmpty,
              !name.trimmingCharacters(in: .whitespaces).isEmpty,
              !userId.trimmingCharacters(in: .whitespaces).isEmpty
        else {
            errorMessage = "Please fill in all the Fields"
            return false
        }
        
        guard email.contains("@") && email.contains(".") else {
            errorMessage = "Enter a valid Email"
            return false
        }
        
        guard password.count > 6 else {
            errorMessage = "Enter a password length greater than 6"
            return false
        }
        
        guard password == confirmPassword else {
            errorMessage = "Passwords are not matching"
            return false
        }
        
        // Validate username format (alphanumeric, 3-20 characters)
        let usernameRegex = "^[a-zA-Z0-9]{3,20}$"
        let usernamePredicate = NSPredicate(format: "SELF MATCHES %@", usernameRegex)
        guard usernamePredicate.evaluate(with: userId) else {
            errorMessage = "Username must be 3-20 characters and contain only letters and numbers"
            return false
        }
        
        return true
    }
}
