//
//  AuthenticationManager.swift
//  Geolocation_v1.0.0
//
//  Handles "Continue with Google" and "Sign in with Apple" on top of the
//  existing Firebase email/password auth. The two hard requirements are:
//
//   1. No duplicate Firebase Auth accounts. If the social email already belongs
//      to an email/password account (Firebase's default "one account per email
//      address" setting), we LINK the social provider to that existing account
//      instead of creating a second one — asking the user to confirm their
//      password so the link is authorized.
//
//   2. No duplicate Firestore `users` profiles. After Firebase sign-in we look
//      up the profile by email; if one already exists we just load it, otherwise
//      we create a single new profile with an auto-generated unique username.
//
//  Google and Apple both return verified emails, so `isEmailVerified` is true
//  and MainViewModel routes the user straight to HomeView — no email
//  verification step is needed for social sign-in.
//

import Foundation
import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import GoogleSignIn
import AuthenticationServices
import CryptoKit
import UIKit

class AuthenticationManager: ObservableObject {

    /// Shared singleton. AuthenticationManager must outlive LoginView: the moment
    /// a social sign-in succeeds, MainView swaps LoginView out for HomeView, which
    /// would deallocate a view-owned instance *while the Firestore profile write
    /// is still in flight* — silently dropping the write. A singleton survives the
    /// view teardown so provisioning always completes.
    static let shared = AuthenticationManager()

    /// Shown over the login form while a social sign-in is in flight.
    @Published var isLoading: Bool = false
    /// User-facing error message; LoginView surfaces it like the other forms.
    @Published var errorMessage: String = ""
    /// Set when a social email collides with an existing password account and we
    /// need the user's password to LINK (not duplicate) the accounts. LoginView
    /// observes this to present the password sheet.
    @Published var pendingLink: PendingLink? = nil
    /// Error shown inside the link sheet (kept separate from `errorMessage` so it
    /// doesn't trigger the login screen's alert behind the sheet).
    @Published var linkErrorMessage: String = ""

    /// A social credential waiting to be linked to an existing password account.
    struct PendingLink: Identifiable {
        let id = UUID()
        let email: String
        let credential: AuthCredential
        let providerLabel: String
        /// Carried through so the new provider's name can seed a missing profile.
        let displayName: String?
    }

    /// Raw nonce for the in-flight Apple request; validated by Firebase against
    /// the hashed nonce embedded in the returned identity token.
    private var currentNonce: String?

    private let db = Firestore.firestore()

    private init() {}

    // MARK: - Google

    /// Starts the Google sign-in flow and exchanges the result for a Firebase
    /// credential. Safe to call from the LoginView button.
    func signInWithGoogle() {
        guard !isLoading else { return }

        guard let clientID = FirebaseApp.app()?.options.clientID else {
            self.errorMessage = "Google Sign-In is not configured correctly. Please try again later."
            return
        }

        // Ensure GIDSignIn is configured even if it wasn't set at launch.
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)

        guard let presenter = Self.topViewController() else {
            self.errorMessage = "Unable to present Google Sign-In. Please try again."
            return
        }

        isLoading = true
        errorMessage = ""

        GIDSignIn.sharedInstance.signIn(withPresenting: presenter) { [weak self] result, error in
            guard let self = self else { return }

            if let error = error {
                // The user cancelling the sheet isn't an error worth surfacing.
                let nsError = error as NSError
                if nsError.code == GIDSignInError.canceled.rawValue {
                    DispatchQueue.main.async { self.isLoading = false }
                    return
                }
                self.finish(error: "Google Sign-In failed: \(error.localizedDescription)")
                return
            }

            guard let gidUser = result?.user,
                  let idToken = gidUser.idToken?.tokenString else {
                self.finish(error: "Google Sign-In failed: missing credentials. Please try again.")
                return
            }

            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: gidUser.accessToken.tokenString
            )

            self.firebaseSignIn(with: credential,
                                displayName: gidUser.profile?.name,
                                providerLabel: "Google")
        }
    }

    // MARK: - Apple

    /// Configure the `SignInWithAppleButton` request: request name/email and bind
    /// a fresh hashed nonce so Firebase can verify the returned token.
    func configureAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = Self.randomNonceString()
        currentNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(nonce)
    }

    /// Handle the `SignInWithAppleButton` completion and exchange the Apple
    /// credential for a Firebase credential.
    func handleAppleCompletion(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .failure(let error):
            // Cancellation surfaces as ASAuthorizationError.canceled — stay quiet.
            if let authError = error as? ASAuthorizationError, authError.code == .canceled {
                return
            }
            self.errorMessage = "Sign in with Apple failed: \(error.localizedDescription)"

        case .success(let authorization):
            guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                self.errorMessage = "Sign in with Apple failed: unexpected credential."
                return
            }
            guard let nonce = currentNonce else {
                self.errorMessage = "Sign in with Apple failed: invalid state. Please try again."
                return
            }
            guard let appleIDToken = appleIDCredential.identityToken,
                  let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
                self.errorMessage = "Sign in with Apple failed: unable to read identity token."
                return
            }

            isLoading = true
            errorMessage = ""

            let credential = OAuthProvider.appleCredential(
                withIDToken: idTokenString,
                rawNonce: nonce,
                fullName: appleIDCredential.fullName
            )

            // Apple only sends the full name on the very first authorization, so
            // capture it here to seed a brand-new profile.
            let displayName = Self.formattedName(from: appleIDCredential.fullName)

            firebaseSignIn(with: credential, displayName: displayName, providerLabel: "Apple")
        }
    }

    // MARK: - Account linking (no duplicate Auth accounts)

    /// Finish linking a pending social credential to an existing password account.
    /// Called by LoginView's password sheet. Signs in with the password, links the
    /// social provider onto that same account, then ensures the profile is loaded.
    func completeLinkWithPassword(_ password: String) {
        guard let pending = pendingLink else { return }
        guard !password.isEmpty else {
            self.linkErrorMessage = "Please enter your password to continue."
            return
        }

        isLoading = true
        linkErrorMessage = ""
        // The password account is an existing user, but guard the brief window in
        // case its Firestore profile is somehow missing.
        UserSessionManager.shared.isProvisioningProfile = true

        Auth.auth().signIn(withEmail: pending.email, password: password) { [weak self] result, error in
            guard let self = self else { return }

            if let error = error {
                self.finishLink(error: self.parseAuthError(error))
                return
            }

            guard let user = result?.user else {
                self.finishLink(error: "Unable to link your account. Please try again.")
                return
            }

            user.link(with: pending.credential) { [weak self] _, linkError in
                guard let self = self else { return }

                if let linkError = linkError {
                    let code = (linkError as NSError).code
                    // Already linked (e.g. a previous attempt succeeded) — treat as success.
                    if code == AuthErrorCode.providerAlreadyLinked.rawValue ||
                       code == AuthErrorCode.credentialAlreadyInUse.rawValue {
                        DispatchQueue.main.async { self.pendingLink = nil }
                        self.ensureUserDocument(for: user, displayName: pending.displayName)
                        return
                    }
                    self.finishLink(error: "Couldn't link your \(pending.providerLabel) account: \(linkError.localizedDescription)")
                    return
                }

                DispatchQueue.main.async { self.pendingLink = nil }
                self.ensureUserDocument(for: user, displayName: pending.displayName)
            }
        }
    }

    /// Abandon a pending link (user dismissed the password sheet).
    func cancelPendingLink() {
        // Sign out the half-finished social attempt so no stale session lingers.
        try? Auth.auth().signOut()
        UserSessionManager.shared.isProvisioningProfile = false
        DispatchQueue.main.async {
            self.pendingLink = nil
            self.linkErrorMessage = ""
            self.isLoading = false
        }
    }

    // MARK: - Shared Firebase sign-in

    private func firebaseSignIn(with credential: AuthCredential, displayName: String?, providerLabel: String) {
        // Suppress the transient "profile not found" error that the auth-state
        // listener would otherwise show for a brand-new social user before we've
        // had a chance to create their Firestore profile.
        UserSessionManager.shared.isProvisioningProfile = true

        Auth.auth().signIn(with: credential) { [weak self] result, error in
            guard let self = self else { return }

            if let error = error {
                let nsError = error as NSError

                // The email already belongs to a different provider (typically an
                // email/password account). Link instead of creating a duplicate.
                if nsError.code == AuthErrorCode.accountExistsWithDifferentCredential.rawValue {
                    self.handleExistingAccount(error: nsError, displayName: displayName, providerLabel: providerLabel)
                    return
                }

                UserSessionManager.shared.isProvisioningProfile = false
                self.finish(error: "\(providerLabel) Sign-In failed: \(error.localizedDescription)")
                return
            }

            guard let user = result?.user else {
                UserSessionManager.shared.isProvisioningProfile = false
                self.finish(error: "\(providerLabel) Sign-In failed. Please try again.")
                return
            }

            self.ensureUserDocument(for: user, displayName: displayName)
        }
    }

    /// Resolve an `accountExistsWithDifferentCredential` error into a link flow.
    private func handleExistingAccount(error nsError: NSError, displayName: String?, providerLabel: String) {
        let email = nsError.userInfo[AuthErrorUserInfoEmailKey] as? String ?? ""
        let pendingCredential = nsError.userInfo[AuthErrorUserInfoUpdatedCredentialKey] as? AuthCredential

        guard !email.isEmpty, let pendingCredential = pendingCredential else {
            UserSessionManager.shared.isProvisioningProfile = false
            self.finish(error: "An account already exists with this email. Please sign in with your original method.")
            return
        }

        Auth.auth().fetchSignInMethods(forEmail: email) { [weak self] methods, _ in
            guard let self = self else { return }
            UserSessionManager.shared.isProvisioningProfile = false

            let methods = methods ?? []
            let passwordMethod = EmailAuthProvider.id // "password"

            // If a password account exists (or email-enumeration protection hid
            // the methods list), ask for the password to authorize linking.
            if methods.contains(passwordMethod) || methods.isEmpty {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.pendingLink = PendingLink(
                        email: email,
                        credential: pendingCredential,
                        providerLabel: providerLabel,
                        displayName: displayName
                    )
                }
            } else if methods.contains("google.com") {
                self.finish(error: "This email is already registered with Google. Please use \"Continue with Google\".")
            } else if methods.contains("apple.com") {
                self.finish(error: "This email is already registered with Apple. Please use \"Sign in with Apple\".")
            } else {
                self.finish(error: "An account already exists with this email. Please sign in with your original provider.")
            }
        }
    }

    // MARK: - Firestore profile (no duplicate profiles)

    /// Ensure exactly one Firestore `users` profile exists for this account.
    /// Looks up by email (profiles are keyed by username, so this is how the rest
    /// of the app resolves them too). Creates one only when none is found.
    private func ensureUserDocument(for user: FirebaseAuth.User, displayName: String?) {
        guard let email = user.email, !email.isEmpty else {
            UserSessionManager.shared.isProvisioningProfile = false
            self.finish(error: "Your account is missing an email address and can't be set up.")
            return
        }

        db.collection("users")
            .whereField("email", isEqualTo: email)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }

                if let error = error {
                    UserSessionManager.shared.isProvisioningProfile = false
                    self.finish(error: "Couldn't load your profile: \(error.localizedDescription)")
                    return
                }

                // Existing profile — just load it. No duplicate created.
                if snapshot?.documents.first != nil {
                    self.loadSessionAndFinish()
                    return
                }

                // No profile yet — create a single new one with a unique username.
                let seed = displayName?.isEmpty == false ? displayName! : String(email.prefix(while: { $0 != "@" }))
                self.generateUniqueUsername(seed: seed) { username in
                    let newUser = User(
                        userId: username,
                        name: (displayName?.isEmpty == false ? displayName! : "New User"),
                        email: email,
                        joined: Date().timeIntervalSince1970,
                        isSubscribed: false,
                        subscriptionToken: UUID().uuidString
                    )

                    self.db.collection("users")
                        .document(username)
                        .setData(newUser.asDict()) { [weak self] error in
                            guard let self = self else { return }
                            if let error = error {
                                UserSessionManager.shared.isProvisioningProfile = false
                                self.finish(error: "Couldn't create your profile: \(error.localizedDescription)")
                                return
                            }
                            self.loadSessionAndFinish()
                        }
                }
            }
    }

    private func loadSessionAndFinish() {
        DispatchQueue.main.async {
            self.isLoading = false
            self.errorMessage = ""
            UserSessionManager.shared.isProvisioningProfile = false
            UserSessionManager.shared.fetchUser()
        }
    }

    /// Produce a Firestore-safe username that isn't already taken.
    /// Sanitizes the seed to `[a-z0-9]` (3–20 chars) and appends random digits
    /// on collision, falling back to a fully random handle after a few tries.
    private func generateUniqueUsername(seed: String, attempt: Int = 0, completion: @escaping (String) -> Void) {
        let candidate: String
        if attempt == 0 {
            var base = seed.lowercased().filter { $0.isLetter || $0.isNumber }
            if base.count < 3 { base = "user" + base }
            candidate = String(base.prefix(20))
        } else if attempt < 5 {
            var base = seed.lowercased().filter { $0.isLetter || $0.isNumber }
            if base.isEmpty { base = "user" }
            let suffix = String(Int.random(in: 1000...9999))
            candidate = String(base.prefix(20 - suffix.count)) + suffix
        } else {
            // Give up on the seed and use a guaranteed-unique-ish random handle.
            candidate = "user" + String(UUID().uuidString.prefix(8)).lowercased()
        }

        db.collection("users").document(candidate).getDocument { [weak self] document, error in
            guard let self = self else { return }
            // On read error, fall back to the candidate rather than blocking signup.
            if error != nil || document?.exists == false {
                completion(candidate)
            } else {
                self.generateUniqueUsername(seed: seed, attempt: attempt + 1, completion: completion)
            }
        }
    }

    // MARK: - Helpers

    private func finish(error: String) {
        UserSessionManager.shared.isProvisioningProfile = false
        DispatchQueue.main.async {
            self.isLoading = false
            self.errorMessage = error
        }
    }

    /// Error terminus for the link sheet — keeps the sheet open and shows the
    /// message inline instead of via the login screen's alert.
    private func finishLink(error: String) {
        UserSessionManager.shared.isProvisioningProfile = false
        DispatchQueue.main.async {
            self.isLoading = false
            self.linkErrorMessage = error
        }
    }

    private func parseAuthError(_ error: Error) -> String {
        switch (error as NSError).code {
        case AuthErrorCode.wrongPassword.rawValue, AuthErrorCode.invalidCredential.rawValue:
            return "Incorrect password. Please double-check it and try again."
        case AuthErrorCode.tooManyRequests.rawValue:
            return "Too many attempts. Please wait a few minutes and try again."
        case AuthErrorCode.networkError.rawValue:
            return "Network error. Please check your connection and try again."
        default:
            return "Couldn't verify your account: \(error.localizedDescription)"
        }
    }

    private static func formattedName(from components: PersonNameComponents?) -> String? {
        guard let components = components else { return nil }
        let name = PersonNameComponentsFormatter().string(from: components).trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? nil : name
    }

    /// Find the top-most view controller to present the Google sign-in sheet from.
    private static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
            ?? UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first

        var top = scene?.windows.first(where: { $0.isKeyWindow })?.rootViewController
            ?? scene?.windows.first?.rootViewController

        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }

    // MARK: - Nonce (required for Sign in with Apple + Firebase)

    private static func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length

        while remaining > 0 {
            let randoms: [UInt8] = (0..<16).map { _ in
                var random: UInt8 = 0
                let status = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if status != errSecSuccess {
                    fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(status)")
                }
                return random
            }

            randoms.forEach { random in
                if remaining == 0 { return }
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remaining -= 1
                }
            }
        }

        return result
    }

    private static func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashed = SHA256.hash(data: inputData)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }
}
