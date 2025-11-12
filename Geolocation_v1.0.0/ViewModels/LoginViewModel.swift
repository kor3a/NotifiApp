//
//  LoginViewModel.swift
//  Geolocation_v1.0.0
//
//  Created by Subong Jeon on 8/5/24.
//

import Foundation
import FirebaseAuth

class LoginViewModel: ObservableObject {
    @Published var email: String = ""
    @Published var password: String = ""
    @Published var errorMessage: String = ""
    
    init() {}
    
    func login() {
        guard validate() else {
            return
        }

        // Clear previous error messages
        errorMessage = ""

        Auth.auth().signIn(withEmail: email, password: password) { [weak self] result, error in
            guard let self = self else { return }

            if let error = error {
                // Display Firebase auth error to user
                DispatchQueue.main.async {
                    self.errorMessage = self.parseAuthError(error)
                }
            } else {
                // Fetch user data immediately after successful login
                UserSessionManager.shared.fetchUser()
            }
        }
    }

    private func parseAuthError(_ error: Error) -> String {
        let errorCode = (error as NSError).code

        switch errorCode {
        case AuthErrorCode.wrongPassword.rawValue:
            return "Incorrect password. Please double-check your password and try again. If you've forgotten it, use the 'Forgot password?' link below."
        case AuthErrorCode.invalidEmail.rawValue:
            return "The email address format is invalid. Please enter a valid email address (e.g., example@email.com)."
        case AuthErrorCode.userNotFound.rawValue:
            return "No account found with this email address. Please check your email or sign up to create a new account."
        case AuthErrorCode.userDisabled.rawValue:
            return "This account has been disabled. Please contact support for assistance."
        case AuthErrorCode.networkError.rawValue:
            return "Network connection error. Please check your internet connection and try again."
        case AuthErrorCode.tooManyRequests.rawValue:
            return "Too many unsuccessful login attempts. For security reasons, please wait a few minutes before trying again."
        case AuthErrorCode.invalidCredential.rawValue:
            return "The email or password you entered is incorrect. Please verify your credentials and try again."
        case AuthErrorCode.emailAlreadyInUse.rawValue:
            return "This email address is already registered. Please login or use a different email."
        case AuthErrorCode.weakPassword.rawValue:
            return "Your password is too weak. Please use at least 6 characters with a mix of letters and numbers."
        default:
            // Provide a more user-friendly default message
            let nsError = error as NSError
            if let errorMessage = nsError.userInfo["NSLocalizedDescription"] as? String {
                return "Login failed: \(errorMessage)"
            }
            return "An unexpected error occurred. Please try again or contact support if the problem persists."
        }
    }
    
    func validate() -> Bool {
        guard !email.trimmingCharacters(in: .whitespaces).isEmpty,
              !password.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Please enter both your email address and password to continue."
            return false
        }

        guard email.contains("@") && email.contains(".") else {
            errorMessage = "Please enter a valid email address in the format: example@email.com"
            return false
        }

        return true
    }
}
