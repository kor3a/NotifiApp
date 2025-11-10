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

        Auth.auth().signIn(withEmail: email, password: password) { result, error in
            if error == nil {
                // Fetch user data immediately after successful login
                UserSessionManager.shared.fetchUser()
            }
        }
    }
    
    func validate() -> Bool {
        guard !email.trimmingCharacters(in: .whitespaces).isEmpty,
              !password.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Enter a valid Email/Password. Fill in all the Fields"
            return false
        }
        
        guard email.contains("@") && email.contains(".") else {
            errorMessage = "Enter a valid Email"
            return false
        }
        
        return true
    }
}
