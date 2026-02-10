//
//  MainViewModel.swift
//  Geolocation_v1.0.0
//
//  Created by Subong Jeon on 8/5/24.
//

import Foundation
import FirebaseAuth

class MainViewModel: NSObject, ObservableObject {
    
    @Published var currentUserId: String = ""
    private var handler: AuthStateDidChangeListenerHandle?
    
    public var isSignedIn: Bool {
        guard let user = Auth.auth().currentUser else { return false }
        return user.isEmailVerified
    }

     override init() {
         super.init()

         self.handler = Auth.auth().addStateDidChangeListener({ [weak self] _, user in
            DispatchQueue.main.async {
                self?.currentUserId = user?.uid ?? ""

                // Only fetch user data for verified users; clear session otherwise
                if let user = user, user.isEmailVerified {
                    UserSessionManager.shared.fetchUser()
                } else {
                    UserSessionManager.shared.clearSession()
                }
            }
        })
    }
    
    
}
