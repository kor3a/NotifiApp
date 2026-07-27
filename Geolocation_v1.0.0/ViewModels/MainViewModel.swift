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
    @Published var isLoading: Bool = true
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
                self?.isLoading = false

                // Only fetch user data for verified users; clear session otherwise
                if let user = user, user.isEmailVerified {
                    // Route from the cached status synchronously, before any view
                    // renders: a known account goes straight to where it belongs,
                    // and an account this device hasn't resolved yet waits on the
                    // launch screen rather than flashing the app it may not want.
                    UserSessionManager.shared.profileStatus =
                        UserSessionManager.cachedProfileStatus(uid: user.uid) ?? .resolving
                    UserSessionManager.shared.fetchUser()
                } else {
                    UserSessionManager.shared.clearSession()
                }
            }
        })
    }


}
