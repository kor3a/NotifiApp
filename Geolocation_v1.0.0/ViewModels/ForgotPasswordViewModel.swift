//
//  ForgotPasswordViewModel.swift
//  Geolocation_v1.0.0
//
//  Created by Claude on 11/17/25.
//

import Foundation
import FirebaseAuth

class ForgotPasswordViewModel: ObservableObject {
    @Published var email: String = ""
    @Published var errorMessage: String = ""
    @Published var successMessage: String = ""
    @Published var isLoading: Bool = false

    init() {}

    func sendPasswordReset() {
        guard validate() else {
            return
        }

        // Clear previous messages
        errorMessage = ""
        successMessage = ""
        isLoading = true

        Auth.auth().sendPasswordReset(withEmail: email) { [weak self] error in
            guard let self = self else { return }

            DispatchQueue.main.async {
                self.isLoading = false

                if let error = error {
                    self.errorMessage = self.parseAuthError(error)
                } else {
                    self.successMessage = "Password reset email sent! Please check your inbox and follow the instructions to reset your password."
                }
            }
        }
    }

    private func parseAuthError(_ error: Error) -> String {
        let errorCode = (error as NSError).code

        switch errorCode {
        case AuthErrorCode.invalidEmail.rawValue:
            return "The email address format is invalid. Please enter a valid email address (e.g., example@email.com)."
        case AuthErrorCode.userNotFound.rawValue:
            return "No account found with this email address. Please check your email or sign up to create a new account."
        case AuthErrorCode.networkError.rawValue:
            return "Network connection error. Please check your internet connection and try again."
        case AuthErrorCode.tooManyRequests.rawValue:
            return "Too many requests. Please wait a few minutes before trying again."
        default:
            let nsError = error as NSError
            if let errorMessage = nsError.userInfo["NSLocalizedDescription"] as? String {
                return "Password reset failed: \(errorMessage)"
            }
            return "An unexpected error occurred. Please try again or contact support if the problem persists."
        }
    }

    func validate() -> Bool {
        guard !email.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Please enter your email address."
            return false
        }

        guard email.contains("@") && email.contains(".") else {
            errorMessage = "Please enter a valid email address in the format: example@email.com"
            return false
        }

        return true
    }
}
