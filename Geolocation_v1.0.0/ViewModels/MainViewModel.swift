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
                    // Restore the pending-setup marker synchronously, before any
                    // view renders, so a social signup that was interrupted before
                    // its profile was written resumes at setup instead of flashing
                    // the main app while the profile lookup runs.
                    if UserSessionManager.isProfileSetupPending(uid: user.uid) {
                        UserSessionManager.shared.needsProfileSetup = true
                    }
                    UserSessionManager.shared.fetchUser()
                } else {
                    UserSessionManager.shared.clearSession()
                }
            }
        })
    }


}
