//
//  ProfileViewModel.swift
//  Geolocation_v1.0.0
//
//  Created by James Jeon on 10/13/24.
//

import Foundation
import Firebase
import FirebaseAuth
import FirebaseFirestore

class ProfileViewModel: ObservableObject {
    
    init() {}
    
    @Published var user: User? = nil
    
    func fetchUser() {
        guard let userId = Auth.auth().currentUser?.uid else {
            return
        }
        
        let db = Firestore.firestore()
        
        db.collection("users").document(userId).getDocument { [weak self] data, error in
            guard let userData = data?.data(), error == nil else {
                return
            }
            
            DispatchQueue.main.async {
                self?.user = User(userId: userData["id"] as? String ?? "", name: userData["name"] as? String ?? "", email: userData["email"] as? String ?? "", joined: userData["joined"] as? TimeInterval ?? 0)
            }
        }
    }
    
    func signOut() {
        do {
            try Auth.auth().signOut()
        } catch {
            print("Could not sign out")
        }
    }
}
