//
//  UserSessionManager.swift
//  Geolocation_v1.0.0
//
//  Created on 11/10/24.
//

import Foundation
import Firebase
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import Combine

class UserSessionManager: ObservableObject {
    static let shared = UserSessionManager()

    @Published var currentUser: User? = nil
    @Published var isLoading: Bool = false
    @Published var errorMessage: String = ""

    private init() {
        // Private initializer for singleton
    }

    // Fetch user data from Firestore
    func fetchUser() {
        // Get the current authenticated user's email
        guard let currentUserEmail = Auth.auth().currentUser?.email else {
            DispatchQueue.main.async {
                self.errorMessage = "No authenticated user found"
                self.isLoading = false
            }
            return
        }

        #if DEBUG
        print("UserSessionManager: Fetching user with email: \(currentUserEmail)")
        #endif
        isLoading = true
        let db = Firestore.firestore()

        // Query to find user by email since we store documents by username
        db.collection("users")
            .whereField("email", isEqualTo: currentUserEmail)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }

                if let error = error {
                    #if DEBUG
                    print("UserSessionManager: Error fetching user: \(error.localizedDescription)")
                    #endif
                    DispatchQueue.main.async {
                        self.isLoading = false
                        self.errorMessage = "Error fetching user: \(error.localizedDescription)"
                    }
                    return
                }

                #if DEBUG
                print("UserSessionManager: Query returned \(snapshot?.documents.count ?? 0) documents")
                #endif

                guard let document = snapshot?.documents.first else {
                    #if DEBUG
                    print("UserSessionManager: No documents found for email: \(currentUserEmail)")
                    #endif
                    // Try to fetch all users to debug
                    self.debugFetchAllUsers(email: currentUserEmail)
                    return
                }

                let userData = document.data()
                #if DEBUG
                print("UserSessionManager: Found user data: \(userData)")
                #endif

                DispatchQueue.main.async {
                    self.isLoading = false
                    self.currentUser = User(
                        userId: userData["userId"] as? String ?? "",
                        name: userData["name"] as? String ?? "",
                        email: userData["email"] as? String ?? "",
                        joined: userData["joined"] as? TimeInterval ?? 0,
                        profilePictureURL: userData["profilePictureURL"] as? String,
                        familyMemberIds: userData["familyMemberIds"] as? [String],
                        isSubscribed: userData["isSubscribed"] as? Bool,
                        adminSubscribed: userData["adminSubscribed"] as? Bool
                    )
                }
            }
    }

    private func debugFetchAllUsers(email: String) {
        let db = Firestore.firestore()
        db.collection("users").getDocuments { [weak self] snapshot, error in
            if let error = error {
                #if DEBUG
                print("UserSessionManager: Error fetching all users for debug: \(error.localizedDescription)")
                #endif
                DispatchQueue.main.async {
                    self?.isLoading = false
                    self?.errorMessage = "User data not found. Please ensure your profile was created during signup."
                }
                return
            }

            #if DEBUG
            print("UserSessionManager: Total users in collection: \(snapshot?.documents.count ?? 0)")
            snapshot?.documents.forEach { doc in
                print("UserSessionManager: User document ID: \(doc.documentID), data: \(doc.data())")
            }
            #endif

            DispatchQueue.main.async {
                self?.isLoading = false
                self?.errorMessage = "User data not found in Firestore. Your account may not have completed signup. Please try signing up again."
            }
        }
    }

    // Update user name in Firestore and local cache
    func updateUserName(_ newName: String, completion: @escaping (Bool, String?) -> Void) {
        guard let userId = currentUser?.userId else {
            completion(false, "User ID not found")
            return
        }

        let oldName = currentUser?.name

        let db = Firestore.firestore()
        db.collection("users").document(userId).updateData([
            "name": newName
        ]) { [weak self] error in
            guard let self = self else { return }

            if let error = error {
                completion(false, "Failed to update name: \(error.localizedDescription)")
            } else {
                DispatchQueue.main.async {
                    // Create new User instance to trigger @Published update
                    if var updatedUser = self.currentUser {
                        updatedUser.name = newName
                        self.currentUser = updatedUser
                    }
                }

                // Propagate name change to related documents (friendships, reminders, user_stores)
                if let oldName = oldName, oldName != newName {
                    self.propagateNameChange(userId: userId, oldName: oldName, newName: newName)
                }

                completion(true, nil)
            }
        }
    }

    // MARK: - Name Change Propagation

    /// Propagate a user's name change to all related Firestore documents
    private func propagateNameChange(userId: String, oldName: String, newName: String) {
        let db = Firestore.firestore()

        #if DEBUG
        print("UserSessionManager: Propagating name change from '\(oldName)' to '\(newName)' for userId: \(userId)")
        #endif

        // 1. Update friendships where user is the requester
        db.collection("friends")
            .whereField("requesterId", isEqualTo: userId)
            .getDocuments { snapshot, error in
                if let error = error {
                    #if DEBUG
                    print("UserSessionManager: Error fetching friendships as requester: \(error.localizedDescription)")
                    #endif
                    return
                }

                guard let documents = snapshot?.documents, !documents.isEmpty else { return }

                let batch = db.batch()
                for doc in documents {
                    batch.updateData(["requesterName": newName], forDocument: doc.reference)
                }
                batch.commit { error in
                    #if DEBUG
                    if let error = error {
                        print("UserSessionManager: Error updating requester names: \(error.localizedDescription)")
                    } else {
                        print("UserSessionManager: Updated requesterName in \(documents.count) friendship(s)")
                    }
                    #endif
                }
            }

        // 2. Update friendships where user is the receiver
        db.collection("friends")
            .whereField("receiverId", isEqualTo: userId)
            .getDocuments { snapshot, error in
                if let error = error {
                    #if DEBUG
                    print("UserSessionManager: Error fetching friendships as receiver: \(error.localizedDescription)")
                    #endif
                    return
                }

                guard let documents = snapshot?.documents, !documents.isEmpty else { return }

                let batch = db.batch()
                for doc in documents {
                    batch.updateData(["receiverName": newName], forDocument: doc.reference)
                }
                batch.commit { error in
                    #if DEBUG
                    if let error = error {
                        print("UserSessionManager: Error updating receiver names: \(error.localizedDescription)")
                    } else {
                        print("UserSessionManager: Updated receiverName in \(documents.count) friendship(s)")
                    }
                    #endif
                }
            }

        // 3. Update reminders where sharedFrom matches old name (using sharedFromId for reliable matching)
        db.collection("reminders")
            .whereField("sharedFromId", isEqualTo: userId)
            .getDocuments { snapshot, error in
                if let error = error {
                    #if DEBUG
                    print("UserSessionManager: Error fetching reminders by sharedFromId: \(error.localizedDescription)")
                    #endif
                    return
                }

                guard let documents = snapshot?.documents, !documents.isEmpty else { return }

                let batch = db.batch()
                for doc in documents {
                    batch.updateData(["sharedFrom": newName], forDocument: doc.reference)
                }
                batch.commit { error in
                    #if DEBUG
                    if let error = error {
                        print("UserSessionManager: Error updating sharedFrom in reminders: \(error.localizedDescription)")
                    } else {
                        print("UserSessionManager: Updated sharedFrom in \(documents.count) reminder(s) by ID")
                    }
                    #endif
                }
            }

        // 4. Update reminders where sharedFrom matches old name (fallback for old reminders without sharedFromId)
        db.collection("reminders")
            .whereField("sharedFrom", isEqualTo: oldName)
            .getDocuments { snapshot, error in
                if let error = error {
                    #if DEBUG
                    print("UserSessionManager: Error fetching reminders by sharedFrom name: \(error.localizedDescription)")
                    #endif
                    return
                }

                guard let documents = snapshot?.documents, !documents.isEmpty else { return }

                let batch = db.batch()
                for doc in documents {
                    // Also backfill the sharedFromId for old reminders
                    batch.updateData([
                        "sharedFrom": newName,
                        "sharedFromId": userId
                    ], forDocument: doc.reference)
                }
                batch.commit { error in
                    #if DEBUG
                    if let error = error {
                        print("UserSessionManager: Error updating sharedFrom by name in reminders: \(error.localizedDescription)")
                    } else {
                        print("UserSessionManager: Updated sharedFrom in \(documents.count) reminder(s) by name")
                    }
                    #endif
                }
            }

        // 5. Update sharedWith arrays in reminders (old name -> new name)
        db.collection("reminders")
            .whereField("sharedWith", arrayContains: oldName)
            .getDocuments { snapshot, error in
                if let error = error {
                    #if DEBUG
                    print("UserSessionManager: Error fetching reminders with sharedWith: \(error.localizedDescription)")
                    #endif
                    return
                }

                guard let documents = snapshot?.documents, !documents.isEmpty else { return }

                let batch = db.batch()
                for doc in documents {
                    var sharedWith = doc.data()["sharedWith"] as? [String] ?? []
                    sharedWith = sharedWith.map { $0 == oldName ? newName : $0 }
                    batch.updateData(["sharedWith": sharedWith], forDocument: doc.reference)
                }
                batch.commit { error in
                    #if DEBUG
                    if let error = error {
                        print("UserSessionManager: Error updating sharedWith in reminders: \(error.localizedDescription)")
                    } else {
                        print("UserSessionManager: Updated sharedWith in \(documents.count) reminder(s)")
                    }
                    #endif
                }
            }

        // 6. Update user_stores where sharedFromName matches old name
        db.collection("user_stores")
            .whereField("sharedFrom", isEqualTo: userId)
            .getDocuments { snapshot, error in
                if let error = error {
                    #if DEBUG
                    print("UserSessionManager: Error fetching user_stores by sharedFrom: \(error.localizedDescription)")
                    #endif
                    return
                }

                guard let documents = snapshot?.documents, !documents.isEmpty else { return }

                let batch = db.batch()
                for doc in documents {
                    batch.updateData(["sharedFromName": newName], forDocument: doc.reference)
                }
                batch.commit { error in
                    #if DEBUG
                    if let error = error {
                        print("UserSessionManager: Error updating sharedFromName in user_stores: \(error.localizedDescription)")
                    } else {
                        print("UserSessionManager: Updated sharedFromName in \(documents.count) user_store(s)")
                    }
                    #endif
                }
            }

        // 7. Update user_stores where sharedWith contains old name (owner's perspective)
        db.collection("user_stores")
            .whereField("sharedWith", arrayContains: oldName)
            .getDocuments { snapshot, error in
                if let error = error {
                    #if DEBUG
                    print("UserSessionManager: Error fetching user_stores with sharedWith: \(error.localizedDescription)")
                    #endif
                    return
                }

                guard let documents = snapshot?.documents, !documents.isEmpty else { return }

                let batch = db.batch()
                for doc in documents {
                    var sharedWith = doc.data()["sharedWith"] as? [String] ?? []
                    sharedWith = sharedWith.map { $0 == oldName ? newName : $0 }
                    batch.updateData(["sharedWith": sharedWith], forDocument: doc.reference)
                }
                batch.commit { error in
                    #if DEBUG
                    if let error = error {
                        print("UserSessionManager: Error updating sharedWith in user_stores: \(error.localizedDescription)")
                    } else {
                        print("UserSessionManager: Updated sharedWith in \(documents.count) user_store(s)")
                    }
                    #endif
                }
            }

        // 8. Update user_stores where userName matches old name (recipient's own store doc)
        db.collection("user_stores")
            .whereField("userId", isEqualTo: userId)
            .getDocuments { snapshot, error in
                if let error = error {
                    #if DEBUG
                    print("UserSessionManager: Error fetching user's own user_stores: \(error.localizedDescription)")
                    #endif
                    return
                }

                guard let documents = snapshot?.documents, !documents.isEmpty else { return }

                let batch = db.batch()
                var updatedCount = 0
                for doc in documents {
                    let data = doc.data()
                    if let userName = data["userName"] as? String, userName == oldName {
                        batch.updateData(["userName": newName], forDocument: doc.reference)
                        updatedCount += 1
                    }
                }
                if updatedCount > 0 {
                    batch.commit { error in
                        #if DEBUG
                        if let error = error {
                            print("UserSessionManager: Error updating userName in user_stores: \(error.localizedDescription)")
                        } else {
                            print("UserSessionManager: Updated userName in \(updatedCount) user_store(s)")
                        }
                        #endif
                    }
                }
            }

        // 9. Update conversation participantNames
        db.collection("conversations")
            .whereField("participantIds", arrayContains: userId)
            .getDocuments { snapshot, error in
                if let error = error {
                    #if DEBUG
                    print("UserSessionManager: Error fetching conversations: \(error.localizedDescription)")
                    #endif
                    return
                }

                guard let documents = snapshot?.documents, !documents.isEmpty else { return }

                let batch = db.batch()
                for doc in documents {
                    batch.updateData(["participantNames.\(userId)": newName], forDocument: doc.reference)
                }
                batch.commit { error in
                    #if DEBUG
                    if let error = error {
                        print("UserSessionManager: Error updating participantNames in conversations: \(error.localizedDescription)")
                    } else {
                        print("UserSessionManager: Updated participantNames in \(documents.count) conversation(s)")
                    }
                    #endif
                }
            }
    }

    // Update profile picture URL in Firestore and local cache
    func updateProfilePictureURL(_ url: String, completion: @escaping (Bool, String?) -> Void) {
        guard let userId = currentUser?.userId else {
            completion(false, "User ID not found")
            return
        }

        let db = Firestore.firestore()
        db.collection("users").document(userId).updateData([
            "profilePictureURL": url
        ]) { [weak self] error in
            guard let self = self else { return }

            if let error = error {
                completion(false, "Failed to update profile picture: \(error.localizedDescription)")
            } else {
                DispatchQueue.main.async {
                    // Create new User instance to trigger @Published update
                    if var updatedUser = self.currentUser {
                        updatedUser.profilePictureURL = url
                        self.currentUser = updatedUser
                    }
                }
                // Propagate profile picture change to friendship documents so the Friends tab stays current
                self.propagateProfilePictureChange(userId: userId, url: url)
                completion(true, nil)
            }
        }
    }

    // MARK: - Profile Picture Change Propagation

    /// Update the cached profile picture URL stored inside every friendship document for this user.
    /// This keeps the Friends tab in sync — friendship docs snapshot the URL at creation time and
    /// are never refreshed otherwise (unlike the Messages tab which re-fetches from `users`).
    private func propagateProfilePictureChange(userId: String, url: String) {
        let db = Firestore.firestore()

        #if DEBUG
        print("UserSessionManager: Propagating profile picture change for userId: \(userId)")
        #endif

        // 1. Update friendships where user is the requester
        db.collection("friends")
            .whereField("requesterId", isEqualTo: userId)
            .getDocuments { snapshot, error in
                if let error = error {
                    #if DEBUG
                    print("UserSessionManager: Error fetching friendships as requester for picture update: \(error.localizedDescription)")
                    #endif
                    return
                }

                guard let documents = snapshot?.documents, !documents.isEmpty else { return }

                let batch = db.batch()
                for doc in documents {
                    batch.updateData(["requesterProfilePictureURL": url], forDocument: doc.reference)
                }
                batch.commit { error in
                    #if DEBUG
                    if let error = error {
                        print("UserSessionManager: Error updating requesterProfilePictureURL: \(error.localizedDescription)")
                    } else {
                        print("UserSessionManager: Updated requesterProfilePictureURL in \(documents.count) friendship(s)")
                    }
                    #endif
                }
            }

        // 2. Update friendships where user is the receiver
        db.collection("friends")
            .whereField("receiverId", isEqualTo: userId)
            .getDocuments { snapshot, error in
                if let error = error {
                    #if DEBUG
                    print("UserSessionManager: Error fetching friendships as receiver for picture update: \(error.localizedDescription)")
                    #endif
                    return
                }

                guard let documents = snapshot?.documents, !documents.isEmpty else { return }

                let batch = db.batch()
                for doc in documents {
                    batch.updateData(["receiverProfilePictureURL": url], forDocument: doc.reference)
                }
                batch.commit { error in
                    #if DEBUG
                    if let error = error {
                        print("UserSessionManager: Error updating receiverProfilePictureURL: \(error.localizedDescription)")
                    } else {
                        print("UserSessionManager: Updated receiverProfilePictureURL in \(documents.count) friendship(s)")
                    }
                    #endif
                }
            }
    }

    // Add a friend to the family group
    func addFamilyMember(_ friendId: String, completion: @escaping (Bool, String?) -> Void) {
        guard let userId = currentUser?.userId else {
            completion(false, "User ID not found")
            return
        }

        let db = Firestore.firestore()
        db.collection("users").document(userId).updateData([
            "familyMemberIds": FieldValue.arrayUnion([friendId])
        ]) { [weak self] error in
            guard let self = self else { return }

            if let error = error {
                completion(false, "Failed to add family member: \(error.localizedDescription)")
            } else {
                DispatchQueue.main.async {
                    if var updatedUser = self.currentUser {
                        var ids = updatedUser.familyMemberIds ?? []
                        if !ids.contains(friendId) {
                            ids.append(friendId)
                        }
                        updatedUser.familyMemberIds = ids
                        self.currentUser = updatedUser
                    }
                }
                completion(true, nil)
            }
        }
    }

    // Remove a friend from the family group
    func removeFamilyMember(_ friendId: String, completion: @escaping (Bool, String?) -> Void) {
        guard let userId = currentUser?.userId else {
            completion(false, "User ID not found")
            return
        }

        let db = Firestore.firestore()
        db.collection("users").document(userId).updateData([
            "familyMemberIds": FieldValue.arrayRemove([friendId])
        ]) { [weak self] error in
            guard let self = self else { return }

            if let error = error {
                completion(false, "Failed to remove family member: \(error.localizedDescription)")
            } else {
                DispatchQueue.main.async {
                    if var updatedUser = self.currentUser {
                        var ids = updatedUser.familyMemberIds ?? []
                        ids.removeAll { $0 == friendId }
                        updatedUser.familyMemberIds = ids.isEmpty ? nil : ids
                        self.currentUser = updatedUser
                    }
                }
                completion(true, nil)
            }
        }
    }

    // MARK: - Account Deletion

    /// Permanently deletes the user's account and all associated data.
    /// Deletes Firebase Auth user first, then Firestore documents and Storage files.
    func deleteAccount(completion: @escaping (Bool, String?) -> Void) {
        guard let user = currentUser,
              let authUser = Auth.auth().currentUser else {
            completion(false, "No authenticated user found")
            return
        }

        let userId = user.userId

        // 1. Delete Firebase Auth user first — if this fails (e.g. requiresRecentLogin),
        //    no Firestore data has been touched yet, so the account remains intact.
        authUser.delete { error in
            if let error = error {
                let nsError = error as NSError
                if nsError.code == AuthErrorCode.requiresRecentLogin.rawValue {
                    completion(false, "For security, please sign out and sign back in before deleting your account.")
                } else {
                    completion(false, "Failed to delete account: \(error.localizedDescription)")
                }
                return
            }

            // Auth deletion succeeded — now clean up all associated data.
            // Auth listener in MainViewModel will call clearSession automatically.
            let db = Firestore.firestore()
            let group = DispatchGroup()

            // 2. Delete user Firestore document
            group.enter()
            db.collection("users").document(userId).delete { _ in group.leave() }

            // 3. Delete user's reminders
            group.enter()
            db.collection("reminders").whereField("userId", isEqualTo: userId)
                .getDocuments { snapshot, _ in
                    if let docs = snapshot?.documents, !docs.isEmpty {
                        let batch = db.batch()
                        docs.forEach { batch.deleteDocument($0.reference) }
                        batch.commit { _ in group.leave() }
                    } else {
                        group.leave()
                    }
                }

            // 4. Delete user's user_stores
            group.enter()
            db.collection("user_stores").whereField("userId", isEqualTo: userId)
                .getDocuments { snapshot, _ in
                    if let docs = snapshot?.documents, !docs.isEmpty {
                        let batch = db.batch()
                        docs.forEach { batch.deleteDocument($0.reference) }
                        batch.commit { _ in group.leave() }
                    } else {
                        group.leave()
                    }
                }

            // 5. Delete friend connections where user is requester
            group.enter()
            db.collection("friends").whereField("requesterId", isEqualTo: userId)
                .getDocuments { snapshot, _ in
                    if let docs = snapshot?.documents, !docs.isEmpty {
                        let batch = db.batch()
                        docs.forEach { batch.deleteDocument($0.reference) }
                        batch.commit { _ in group.leave() }
                    } else {
                        group.leave()
                    }
                }

            // 6. Delete friend connections where user is receiver
            group.enter()
            db.collection("friends").whereField("receiverId", isEqualTo: userId)
                .getDocuments { snapshot, _ in
                    if let docs = snapshot?.documents, !docs.isEmpty {
                        let batch = db.batch()
                        docs.forEach { batch.deleteDocument($0.reference) }
                        batch.commit { _ in group.leave() }
                    } else {
                        group.leave()
                    }
                }

            // 7. Delete pending friend requests sent by user
            group.enter()
            db.collection("friend_requests").whereField("requesterId", isEqualTo: userId)
                .getDocuments { snapshot, _ in
                    if let docs = snapshot?.documents, !docs.isEmpty {
                        let batch = db.batch()
                        docs.forEach { batch.deleteDocument($0.reference) }
                        batch.commit { _ in group.leave() }
                    } else {
                        group.leave()
                    }
                }

            // 8. Delete pending friend requests received by user
            group.enter()
            db.collection("friend_requests").whereField("receiverId", isEqualTo: userId)
                .getDocuments { snapshot, _ in
                    if let docs = snapshot?.documents, !docs.isEmpty {
                        let batch = db.batch()
                        docs.forEach { batch.deleteDocument($0.reference) }
                        batch.commit { _ in group.leave() }
                    } else {
                        group.leave()
                    }
                }

            // 9. Delete favorite tags
            group.enter()
            db.collection("favorite_tags").whereField("userId", isEqualTo: userId)
                .getDocuments { snapshot, _ in
                    if let docs = snapshot?.documents, !docs.isEmpty {
                        let batch = db.batch()
                        docs.forEach { batch.deleteDocument($0.reference) }
                        batch.commit { _ in group.leave() }
                    } else {
                        group.leave()
                    }
                }

            // 10. Delete profile picture from Storage
            if user.profilePictureURL != nil {
                group.enter()
                let storageRef = Storage.storage().reference()
                storageRef.child("profile_pictures/\(userId).jpg").delete { _ in
                    // Ignore errors; file may not exist
                    group.leave()
                }
            }

            group.notify(queue: .main) {
                completion(true, nil)
            }
        }
    }

    /// Re-authenticates the user with their password, then deletes the account.
    /// Use this when `deleteAccount` fails with a requiresRecentLogin error.
    func reauthenticateAndDeleteAccount(password: String, completion: @escaping (Bool, String?) -> Void) {
        guard let authUser = Auth.auth().currentUser,
              let email = authUser.email else {
            completion(false, "No authenticated user found")
            return
        }

        let credential = EmailAuthProvider.credential(withEmail: email, password: password)
        authUser.reauthenticate(with: credential) { _, error in
            if let error = error {
                let nsError = error as NSError
                if nsError.code == AuthErrorCode.wrongPassword.rawValue {
                    completion(false, "Incorrect password. Please try again.")
                } else {
                    completion(false, "Re-authentication failed: \(error.localizedDescription)")
                }
                return
            }
            self.deleteAccount(completion: completion)
        }
    }

    // Clear user session (call on logout)
    func clearSession() {
        // Only clear if there's actually a session to clear (prevents redundant updates)
        guard currentUser != nil || !errorMessage.isEmpty || isLoading else {
            return
        }

        DispatchQueue.main.async {
            self.currentUser = nil
            self.errorMessage = ""
            self.isLoading = false
        }
    }
}
