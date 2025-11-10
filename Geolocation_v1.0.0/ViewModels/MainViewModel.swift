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
        return Auth.auth().currentUser != nil
    }

     override init() {
         super.init()

         self.handler = Auth.auth().addStateDidChangeListener({ [weak self] _, user in
            DispatchQueue.main.async {
                self?.currentUserId = user?.uid ?? ""

                // Fetch user data when signed in, clear when signed out
                if user != nil {
                    UserSessionManager.shared.fetchUser()
                } else {
                    UserSessionManager.shared.clearSession()
                }
            }
        })
    }
    
    
}
