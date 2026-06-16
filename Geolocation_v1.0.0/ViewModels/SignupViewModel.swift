//
//  SignupViewModel.swift
//  Geolocation_v1.0.0
//
//  Created by Subong Jeon on 8/5/24.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions

class SignupViewModel: ObservableObject {

    @Published var userId: String = ""
    @Published var email: String = ""
    @Published var name: String = ""
    @Published var password: String = ""
    @Published var confirmPassword: String = ""
    @Published var errorMessage: String = ""
    @Published var signupComplete: Bool = false
    @Published var isLoading: Bool = false

    private let db = Firestore.firestore()


    init() {}

    func register() {
        // Prevent concurrent signup attempts (double-tap would otherwise cause a
        // second createUser call to race with the first and return
        // `emailAlreadyInUse` after the first has succeeded).
        guard !isLoading else { return }

        guard validate() else {
            return
        }

        isLoading = true

        // Normalize userId to lowercase for consistency
        let normalizedUserId = userId.lowercased()
        // Normalize email to lowercase (Firebase Auth stores emails in lowercase)
        let normalizedEmail = email.lowercased()

        // Create Firebase Auth user first
        Auth.auth().createUser(withEmail: normalizedEmail, password: self.password) { [weak self] authResult, error in
            guard let self = self else { return }

            if let error = error {
                // A common case: the email belongs to an account from an earlier
                // signup that was never confirmed. Firebase reports this the same
                // way as a fully-registered email ("already in use"), so check the
                // verification status server-side and show a clearer message
                // (and re-send the verification link) instead of a dead end.
                if (error as NSError).code == AuthErrorCode.emailAlreadyInUse.rawValue {
                    self.handleEmailAlreadyInUse(email: normalizedEmail)
                    return
                }
                self.finish(error: "Error creating user: \(error.localizedDescription)")
                return
            }

            guard let user = authResult?.user else {
                self.finish(error: "Failed to retrieve user ID")
                return
            }

            // Now as an authenticated user, check if username is available and create user document
            self.checkUsernameAvailability(for: normalizedUserId) { result in
                switch result {
                case .success(let isAvailable):
                    if !isAvailable {
                        // Username is taken - delete the auth user and show error
                        self.deleteAuthUser(user: user)
                        self.finish(error: "Username is already taken. Please try again with a different username.")
                        return
                    }

                    // Username is available, create user document
                    self.createUser(normalizedUserId: normalizedUserId, normalizedEmail: normalizedEmail, authUserId: user.uid)

                case .failure(let error):
                    // Error checking username - delete the auth user and show error
                    self.deleteAuthUser(user: user)
                    self.finish(error: "Error checking username availability: \(error.localizedDescription)")
                }
            }
        }
    }

    private func finish(error: String) {
        DispatchQueue.main.async {
            self.errorMessage = error
            self.isLoading = false
        }
    }

    /// Resolve an `emailAlreadyInUse` signup failure into a helpful message.
    ///
    /// Asks the `checkEmailVerificationStatus` Cloud Function whether the existing
    /// account has confirmed its email. If it hasn't, the function also re-sends
    /// the verification link, so we tell the user their email is pending
    /// verification rather than showing a generic "already in use" error.
    private func handleEmailAlreadyInUse(email: String) {
        Functions.functions().httpsCallable("checkEmailVerificationStatus").call(["email": email]) { [weak self] result, error in
            guard let self = self else { return }

            if let error = error {
                #if DEBUG
                print("SignupViewModel: checkEmailVerificationStatus failed: \(error.localizedDescription)")
                #endif
                // Fall back to the standard message if the check itself fails.
                self.finish(error: "This email address is already registered. Please log in instead.")
                return
            }

            let status = (result?.data as? [String: Any])?["status"] as? String

            switch status {
            case "pending":
                self.finish(error: "This email is already signed up but not yet verified. We've re-sent the verification link to \(email) — please check your inbox (and spam folder) to finish setting up your account.")
            case "verified":
                self.finish(error: "This email address is already registered. Please log in instead.")
            default:
                // "available" shouldn't happen after an emailAlreadyInUse error,
                // but treat any unexpected result as the generic case.
                self.finish(error: "This email address is already registered. Please log in instead.")
            }
        }
    }
    
    /// Check if username is available
    private func checkUsernameAvailability(for userId: String, completion: @escaping (Result<Bool, Error>) -> Void) {
        guard !userId.isEmpty else {
            #if DEBUG
            print("Username is empty after normalization")
            #endif
            completion(.failure(NSError(domain: "SignupViewModel", code: 1, userInfo: [NSLocalizedDescriptionKey: "Username is empty"])))
            return
        }

        db.collection("users")
            .document(userId)
            .getDocument { (document, error) in
                if let error = error {
                    #if DEBUG
                    print("Error checking username: \(error.localizedDescription)")
                    #endif
                    completion(.failure(error))
                    return
                }

                guard let document = document else {
                    completion(.failure(NSError(domain: "SignupViewModel", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to retrieve document"])))
                    return
                }

                // If no documents are found, username is available
                completion(.success(!document.exists))
            }
    }
    
    /// Create a new User document in Firestore
    private func createUser(normalizedUserId: String, normalizedEmail: String, authUserId: String) {
        let newUser = User(userId: normalizedUserId, name: name, email: normalizedEmail, joined: Date().timeIntervalSince1970, isSubscribed: false, subscriptionToken: UUID().uuidString)
        let userData = newUser.asDict()

        #if DEBUG
        print("SignupViewModel: Creating user document with ID: \(normalizedUserId)")
        print("SignupViewModel: User data to save: \(userData)")
        #endif

        db.collection("users")
            .document(normalizedUserId)
            .setData(userData) { error in
                if let error = error {
                    #if DEBUG
                    print("SignupViewModel: Error saving user: \(error.localizedDescription)")
                    #endif
                    // If we fail to create the Firestore document, we should delete the auth user
                    if let currentUser = Auth.auth().currentUser {
                        self.deleteAuthUser(user: currentUser)
                    }
                    self.finish(error: "Error saving user: \(error.localizedDescription)")
                } else {
                    #if DEBUG
                    print("SignupViewModel: User '\(normalizedUserId)' created successfully in Firestore")
                    #endif

                    // Send verification email before signing out
                    self.sendVerificationEmail()
                }
            }
    }

    /// Send email verification and sign the user out so they must verify before logging in.
    ///
    /// Uses the `sendVerificationEmail` Cloud Function (custom HTML email via Resend)
    /// instead of `user.sendEmailVerification()`, because Firebase Auth's built-in
    /// template is locked and its bare-URL link isn't tappable in many mobile mail
    /// clients. The caller is authenticated here (right after createUser), so the
    /// callable receives the auth context it needs.
    private func sendVerificationEmail() {
        guard Auth.auth().currentUser != nil else {
            self.finish(error: "Failed to send verification email.")
            return
        }

        Functions.functions().httpsCallable("sendVerificationEmail").call { [weak self] _, error in
            guard let self = self else { return }

            if let error = error {
                #if DEBUG
                print("SignupViewModel: Error sending verification email: \(error.localizedDescription)")
                #endif
                // Still proceed - the account was created, they can resend from login
            } else {
                #if DEBUG
                print("SignupViewModel: Verification email sent successfully")
                #endif
            }

            // Sign the user out so they can't use the app until email is verified
            do {
                try Auth.auth().signOut()
                #if DEBUG
                print("SignupViewModel: User signed out after signup, awaiting email verification")
                #endif
            } catch {
                #if DEBUG
                print("SignupViewModel: Error signing out after signup: \(error.localizedDescription)")
                #endif
            }

            DispatchQueue.main.async {
                self.isLoading = false
                self.signupComplete = true
            }
        }
    }

    /// Delete Firebase Auth user (called when signup fails after auth creation)
    private func deleteAuthUser(user: FirebaseAuth.User) {
        user.delete { error in
            if let error = error {
                #if DEBUG
                print("Error deleting auth user: \(error.localizedDescription)")
                #endif
            } else {
                #if DEBUG
                print("Auth user deleted successfully after failed signup")
                #endif
            }
        }
    }
    
    func validate () -> Bool {
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
