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

    @Published var username: String = ""
    @Published var name: String = ""
    @Published var errorMessage: String = ""
    @Published var isLoading: Bool = false
    /// True while a starting username is being generated, so the field can show
    /// a placeholder instead of looking briefly broken.
    @Published var isPreparingSuggestions: Bool = true

    private let db = Firestore.firestore()

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

    /// Prefill the form: the name the provider gave us (Apple sends it only on the
    /// very first authorization, so it was stashed at sign-in) and an available
    /// username derived from that name or the email.
    func loadSuggestions() {
        guard isPreparingSuggestions else { return }

        guard let authUser = Auth.auth().currentUser else {
            isPreparingSuggestions = false
            return
        }

        if name.isEmpty {
            name = UserSessionManager.suggestedName(uid: authUser.uid) ?? ""
        }

        guard username.isEmpty else {
            isPreparingSuggestions = false
            return
        }

        let email = authUser.email ?? ""
        let seed = name.isEmpty ? String(email.prefix(while: { $0 != "@" })) : name

        AuthenticationManager.shared.generateUniqueUsername(seed: seed) { [weak self] suggestion in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if self.username.isEmpty {
                    self.username = suggestion
                }
                self.isPreparingSuggestions = false
            }
        }
    }

    /// Validate the form, claim the username, and write the profile. On success the
    /// session reloads and MainView swaps in the main app.
    func createProfile() {
        guard !isLoading else { return }
        errorMessage = ""

        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else {
            errorMessage = "Please enter your name."
            return
        }

        let normalizedUsername = username.trimmingCharacters(in: .whitespaces).lowercased()
        let predicate = NSPredicate(format: "SELF MATCHES %@", Self.usernameRegex)
        guard predicate.evaluate(with: normalizedUsername) else {
            errorMessage = "Username must be 3-20 characters and contain only letters and numbers."
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
