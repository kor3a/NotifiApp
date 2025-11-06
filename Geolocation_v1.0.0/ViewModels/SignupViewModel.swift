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
        
        // Check if username is available
        checkUsernameAvailability(for: normalizedUserId) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let isAvailable):
                if !isAvailable {
                    self.errorMessage = "Username is already taken"
                    return
                }

                Auth.auth().createUser(withEmail: self.email, password: self.password) { [weak self] result, error in
                    if let error = error {
                        self?.errorMessage = "Error creating user: \(error.localizedDescription)"
                        return
                    }

                    guard result?.user.uid != nil else {
                        self?.errorMessage = "Failed to retrieve user ID"
                        return
                    }

                    self?.createUser(normalizedUserId: normalizedUserId)
                }

            case .failure(let error):
                self.errorMessage = "Error checking username availability: \(error.localizedDescription)"
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
    
    /// Create a new User
    private func createUser(normalizedUserId: String) {
        let newUser = User(userId: normalizedUserId, name: name, email: email, joined: Date().timeIntervalSince1970)
        
        db.collection("users")
            .document(normalizedUserId)
            .setData(newUser.asDict()) { error in
                if let error = error {
                    self.errorMessage = "Error saving user: \(error.localizedDescription)"
                } else {
                    print("User '\(normalizedUserId)' created successfully")
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
