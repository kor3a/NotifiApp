//
//  ProfileSetupViewModel.swift
//  Geolocation_v1.0.0
//
//  Backs the one-time profile setup shown after a first-time Apple/Google
//  sign-in. Social providers give us a verified email but no username, so the
//  user picks their own here instead of being handed a generated one.
//
//  The email is fixed — it comes from the provider and identifies the account
//  (Firestore lookups and security rules both key off it), so it is displayed
//  read-only.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

class ProfileSetupViewModel: ObservableObject {

    /// Always starts blank — the user types their own. Nothing is suggested here
    /// on purpose: a prefilled ID reads as already-decided, and most people kept
    /// whatever was handed to them instead of picking something they wanted.
    @Published var username: String = ""
    @Published var name: String = ""
    @Published var errorMessage: String = ""
    @Published var isLoading: Bool = false

    private let db = Firestore.firestore()

    /// Guards the one-time name prefill, so returning to the screen doesn't undo
    /// an edit the user made (including clearing the field).
    private var hasPrefilledName = false

    /// Same rule as email/password signup, so usernames stay consistent.
    private static let usernameRegex = "^[a-zA-Z0-9]{3,20}$"

    /// The provider-supplied email. Not editable.
    var email: String {
        Auth.auth().currentUser?.email ?? ""
    }

    /// Which provider this account came from, for the explanatory caption.
    var providerLabel: String {
        switch AuthenticationManager.reauthMethod() {
        case .apple: return "Apple"
        case .google: return "Google"
        case .password: return "your account"
        }
    }

    /// Prefill the name the provider gave us — Apple sends it only on the very
    /// first authorization, so it was stashed at sign-in. The username is
    /// deliberately left blank for the user to choose.
    func loadNameSuggestion() {
        guard !hasPrefilledName else { return }
        hasPrefilledName = true

        guard let authUser = Auth.auth().currentUser else { return }

        if name.isEmpty {
            name = UserSessionManager.suggestedName(uid: authUser.uid) ?? ""
        }
    }

    /// Validate the form, claim the username, and write the profile. On success the
    /// session reloads and MainView swaps in the main app.
    func createProfile() {
        guard !isLoading else { return }
        errorMessage = ""

        // Validated in the order the fields are shown, so the message points at
        // the first thing the user would look at.
        let normalizedUsername = username.trimmingCharacters(in: .whitespaces).lowercased()
        guard !normalizedUsername.isEmpty else {
            errorMessage = "Please choose a user ID."
            return
        }

        let predicate = NSPredicate(format: "SELF MATCHES %@", Self.usernameRegex)
        guard predicate.evaluate(with: normalizedUsername) else {
            errorMessage = "Username must be 3-20 characters and contain only letters and numbers."
            return
        }

        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else {
            errorMessage = "Please enter your name."
            return
        }

        guard let authUser = Auth.auth().currentUser,
              let email = authUser.email?.lowercased() else {
            errorMessage = "No authenticated user found. Please sign in again."
            return
        }

        isLoading = true

        // The username is the Firestore document ID, so it has to be free.
        db.collection("users").document(normalizedUsername).getDocument { [weak self] document, error in
            guard let self = self else { return }

            if let error = error {
                self.finish(error: "Couldn't check that username: \(error.localizedDescription)")
                return
            }

            guard document?.exists == false else {
                self.finish(error: "That username is already taken. Please choose another.")
                return
            }

            self.writeProfile(username: normalizedUsername,
                              name: trimmedName,
                              email: email,
                              uid: authUser.uid)
        }
    }

    private func writeProfile(username: String, name: String, email: String, uid: String) {
        let newUser = User(
            userId: username,
            name: name,
            email: email,
            joined: Date().timeIntervalSince1970,
            isSubscribed: false,
            subscriptionToken: UUID().uuidString
        )

        // Suppress the "profile not found" path while the write lands.
        UserSessionManager.shared.isProvisioningProfile = true

        db.collection("users").document(username).setData(newUser.asDict()) { [weak self] error in
            guard let self = self else { return }

            if let error = error {
                UserSessionManager.shared.isProvisioningProfile = false
                self.finish(error: "Couldn't create your profile: \(error.localizedDescription)")
                return
            }

            DispatchQueue.main.async {
                self.isLoading = false
                UserSessionManager.shared.isProvisioningProfile = false
                UserSessionManager.shared.setProfileStatus(.ready)
                UserSessionManager.shared.fetchUser()
            }
        }
    }

    /// Escape hatch — setup is the only screen available until the profile exists,
    /// so the user needs a way back out.
    func signOut() {
        try? Auth.auth().signOut()
    }

    private func finish(error: String) {
        DispatchQueue.main.async {
            self.isLoading = false
            self.errorMessage = error
        }
    }
}
