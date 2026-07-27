//
//  AuthenticationManager.swift
//  Geolocation_v1.0.0
//
//  Handles "Continue with Google" and "Sign in with Apple" on top of the
//  existing Firebase email/password auth. The hard requirements are:
//
//   1. No duplicate Firebase Auth accounts. If the social email already belongs
//      to another account, we LINK the new provider onto the existing account
//      instead of creating a second one:
//        - existing email/password account  -> ask for the password, then link
//        - existing Google/Apple account     -> re-authenticate with that
//          provider, then link the new credential onto it
//
//   2. No duplicate Firestore `users` profiles. After Firebase sign-in we look
//      up the profile by email; if one already exists we just load it, otherwise
//      we create a single new profile with an auto-generated unique username.
//
//  Google and Apple both return verified emails, so `isEmailVerified` is true
//  and MainViewModel routes the user straight to HomeView — no email
//  verification step is needed for social sign-in.
//
//  This is a singleton: it must outlive LoginView, which is torn down the moment
//  a social sign-in succeeds (MainView swaps in HomeView) — a view-owned instance
//  would be deallocated mid-write and silently drop the Firestore profile.
//

import Foundation
import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import GoogleSignIn
import AuthenticationServices
import CryptoKit
import UIKit

class AuthenticationManager: NSObject, ObservableObject {

    static let shared = AuthenticationManager()

    /// Shown over the login form while a social sign-in is in flight.
    @Published var isLoading: Bool = false
    /// User-facing error message; LoginView surfaces it like the other forms.
    @Published var errorMessage: String = ""
    /// Set when a social email collides with an existing *password* account and we
    /// need the user's password to LINK (not duplicate) the accounts.
    @Published var pendingLink: PendingLink? = nil
    /// Error shown inside the password link sheet (kept separate from
    /// `errorMessage` so it doesn't trigger the login alert behind the sheet).
    @Published var linkErrorMessage: String = ""
    /// Set when a social email collides with an existing *Google/Apple* account.
    /// LoginView shows a confirmation, then we re-auth with that provider to link.
    @Published var crossProviderLink: CrossProviderLink? = nil

    /// A social credential waiting to be linked to an existing password account.
    struct PendingLink: Identifiable {
        let id = UUID()
        let email: String
        let credential: AuthCredential
        let providerLabel: String
        /// The provider's name for the user. Linking always lands on an account
        /// that already has a profile, so this is carried for context only —
        /// `firebaseSignIn` stashes the name suggestion for profile setup.
        let displayName: String?
    }

    /// A social credential waiting to be linked onto an existing OAuth account.
    struct CrossProviderLink: Identifiable {
        let id = UUID()
        let email: String
        /// Provider that already owns the email, e.g. "Google" / "Apple".
        let existingProviderLabel: String
        /// Provider the user just tried to sign in with.
        let newProviderLabel: String
        /// Firebase sign-in method id of the existing account ("google.com"/"apple.com").
        let existingMethod: String
        let pendingCredential: AuthCredential
        let displayName: String?
    }

    /// Carries a credential to be linked after re-authenticating with the
    /// existing provider, plus the email that re-auth must match.
    private struct LinkAfter {
        let credential: AuthCredential
        let expectedEmail: String
        let displayName: String?
    }

    /// Raw nonce for the in-flight Apple request; validated by Firebase against
    /// the hashed nonce embedded in the returned identity token.
    private var currentNonce: String?
    /// Set when a *programmatic* Apple sign-in is being used to re-auth for linking.
    private var appleLinkAfter: LinkAfter?
    /// Set when Apple is being used to re-authenticate the *already signed-in* user
    /// (account deletion). Takes priority over the linking path in the delegate.
    private var appleCredentialCompletion: ((CredentialOutcome) -> Void)?

    private let db = Firestore.firestore()

    private override init() {
        super.init()
    }

    // MARK: - Google

    /// Starts the Google sign-in flow and exchanges the result for a Firebase
    /// credential. `linkAfter` is set when Google is being used to re-authenticate
    /// an existing account so another provider's credential can be linked onto it.
    func signInWithGoogle() {
        startGoogleSignIn(linkAfter: nil)
    }

    private func startGoogleSignIn(linkAfter: LinkAfter?) {
        guard !isLoading || linkAfter != nil else { return }

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
                if (error as NSError).code == GIDSignInError.canceled.rawValue {
                    self.abort()
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
                                providerLabel: "Google",
                                linkAfter: linkAfter)
        }
    }

    // MARK: - Apple (SwiftUI button — initial sign-in)

    /// Configure the `SignInWithAppleButton` request: request name/email and bind
    /// a fresh hashed nonce so Firebase can verify the returned token.
    func configureAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = Self.randomNonceString()
        currentNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(nonce)
    }

    /// Handle the `SignInWithAppleButton` completion (initial, non-linking flow).
    func handleAppleCompletion(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .failure(let error):
            if let authError = error as? ASAuthorizationError, authError.code == .canceled {
                return
            }
            self.errorMessage = "Sign in with Apple failed: \(error.localizedDescription)"

        case .success(let authorization):
            guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                self.errorMessage = "Sign in with Apple failed: unexpected credential."
                return
            }
            isLoading = true
            errorMessage = ""
            processAppleCredential(appleIDCredential, linkAfter: nil)
        }
    }

    // MARK: - Apple (programmatic — re-auth for linking)

    /// Trigger Sign in with Apple from code (used to re-authenticate an existing
    /// Apple account so another provider's credential can be linked onto it).
    private func performAppleSignIn(linkAfter: LinkAfter?) {
        let nonce = Self.randomNonceString()
        currentNonce = nonce
        appleLinkAfter = linkAfter

        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(nonce)

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }

    /// Shared Apple credential handling for both the button and programmatic paths.
    private func processAppleCredential(_ appleIDCredential: ASAuthorizationAppleIDCredential, linkAfter: LinkAfter?) {
        guard let nonce = currentNonce else {
            self.finish(error: "Sign in with Apple failed: invalid state. Please try again.")
            return
        }
        guard let appleIDToken = appleIDCredential.identityToken,
              let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            self.finish(error: "Sign in with Apple failed: unable to read identity token.")
            return
        }

        let credential = OAuthProvider.appleCredential(
            withIDToken: idTokenString,
            rawNonce: nonce,
            fullName: appleIDCredential.fullName
        )

        // Apple only sends the full name on the very first authorization.
        let displayName = Self.formattedName(from: appleIDCredential.fullName)

        firebaseSignIn(with: credential, displayName: displayName, providerLabel: "Apple", linkAfter: linkAfter)
    }

    // MARK: - Password account linking

    /// Finish linking a pending social credential to an existing password account.
    func completeLinkWithPassword(_ password: String) {
        guard let pending = pendingLink else { return }
        guard !password.isEmpty else {
            self.linkErrorMessage = "Please enter your password to continue."
            return
        }

        isLoading = true
        linkErrorMessage = ""
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
                    if code == AuthErrorCode.providerAlreadyLinked.rawValue ||
                       code == AuthErrorCode.credentialAlreadyInUse.rawValue {
                        DispatchQueue.main.async { self.pendingLink = nil }
                        self.ensureUserDocument(for: user)
                        return
                    }
                    self.finishLink(error: "Couldn't link your \(pending.providerLabel) account: \(linkError.localizedDescription)")
                    return
                }

                DispatchQueue.main.async { self.pendingLink = nil }
                self.ensureUserDocument(for: user)
            }
        }
    }

    /// Abandon a pending password link (user dismissed the sheet).
    func cancelPendingLink() {
        try? Auth.auth().signOut()
        UserSessionManager.shared.isProvisioningProfile = false
        DispatchQueue.main.async {
            self.pendingLink = nil
            self.linkErrorMessage = ""
            self.isLoading = false
        }
    }

    // MARK: - Cross-provider (OAuth ↔ OAuth) linking

    /// User confirmed they want to link onto their existing Google/Apple account.
    /// Re-authenticate with the existing provider, then link the pending credential.
    func confirmCrossProviderLink() {
        guard let link = crossProviderLink else { return }
        let linkAfter = LinkAfter(credential: link.pendingCredential,
                                  expectedEmail: link.email,
                                  displayName: link.displayName)

        DispatchQueue.main.async { self.crossProviderLink = nil }
        isLoading = true
        errorMessage = ""
        UserSessionManager.shared.isProvisioningProfile = true

        switch link.existingMethod {
        case "google.com":
            startGoogleSignIn(linkAfter: linkAfter)
        case "apple.com":
            performAppleSignIn(linkAfter: linkAfter)
        default:
            finish(error: "Couldn't link your account. Please sign in with your original provider.")
        }
    }

    /// User declined the cross-provider link.
    func cancelCrossProviderLink() {
        try? Auth.auth().signOut()
        UserSessionManager.shared.isProvisioningProfile = false
        DispatchQueue.main.async {
            self.crossProviderLink = nil
            self.isLoading = false
        }
    }

    // MARK: - Shared Firebase sign-in

    private func firebaseSignIn(with credential: AuthCredential,
                                displayName: String?,
                                providerLabel: String,
                                linkAfter: LinkAfter?) {
        // Suppress the transient "profile not found" error that the auth-state
        // listener would otherwise show before we've created the Firestore profile.
        UserSessionManager.shared.isProvisioningProfile = true

        Auth.auth().signIn(with: credential) { [weak self] result, error in
            guard let self = self else { return }

            if let error = error {
                let nsError = error as NSError

                // Only resolve conflicts on an *initial* sign-in. During a linking
                // re-auth we're signing into the owning account, so a conflict here
                // is unexpected and should surface.
                if linkAfter == nil,
                   nsError.code == AuthErrorCode.accountExistsWithDifferentCredential.rawValue {
                    self.handleExistingAccount(error: nsError, displayName: displayName, providerLabel: providerLabel)
                    return
                }

                self.finish(error: "\(providerLabel) Sign-In failed: \(error.localizedDescription)")
                return
            }

            guard let user = result?.user else {
                self.finish(error: "\(providerLabel) Sign-In failed. Please try again.")
                return
            }

            // Stash the provider's name before anything can route to profile setup:
            // the auth-state listener's `fetchUser` runs concurrently with the
            // profile lookup below and may reach setup first, and Apple only ever
            // sends the full name on the very first authorization.
            UserSessionManager.storeSuggestedName(displayName, uid: user.uid)

            // Linking re-auth path: verify the right account, then attach the
            // pending credential from the provider the user originally tried.
            if let linkAfter = linkAfter {
                if let email = user.email,
                   email.lowercased() != linkAfter.expectedEmail.lowercased() {
                    try? Auth.auth().signOut()
                    self.finish(error: "To link your accounts, please sign in with the account for \(linkAfter.expectedEmail).")
                    return
                }

                user.link(with: linkAfter.credential) { [weak self] _, linkError in
                    guard let self = self else { return }
                    if let linkError = linkError {
                        let code = (linkError as NSError).code
                        if code != AuthErrorCode.providerAlreadyLinked.rawValue &&
                           code != AuthErrorCode.credentialAlreadyInUse.rawValue {
                            self.finish(error: "Couldn't link your accounts: \(linkError.localizedDescription)")
                            return
                        }
                    }
                    self.ensureUserDocument(for: user)
                }
                return
            }

            self.ensureUserDocument(for: user)
        }
    }

    /// Resolve an `accountExistsWithDifferentCredential` error into a link flow.
    private func handleExistingAccount(error nsError: NSError, displayName: String?, providerLabel: String) {
        let email = nsError.userInfo[AuthErrorUserInfoEmailKey] as? String ?? ""
        let pendingCredential = nsError.userInfo[AuthErrorUserInfoUpdatedCredentialKey] as? AuthCredential

        guard !email.isEmpty, let pendingCredential = pendingCredential else {
            self.finish(error: "An account already exists with this email. Please sign in with your original method.")
            return
        }

        Auth.auth().fetchSignInMethods(forEmail: email) { [weak self] methods, _ in
            guard let self = self else { return }
            UserSessionManager.shared.isProvisioningProfile = false

            let methods = methods ?? []

            // Existing Google/Apple account -> offer to re-auth with it and link.
            if methods.contains("google.com") {
                self.presentCrossProviderLink(email: email, existingMethod: "google.com",
                                              existingLabel: "Google", newLabel: providerLabel,
                                              credential: pendingCredential, displayName: displayName)
            } else if methods.contains("apple.com") {
                self.presentCrossProviderLink(email: email, existingMethod: "apple.com",
                                              existingLabel: "Apple", newLabel: providerLabel,
                                              credential: pendingCredential, displayName: displayName)
            } else {
                // Password account (or email-enumeration protection hid the list):
                // ask for the password to authorize linking.
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.pendingLink = PendingLink(
                        email: email,
                        credential: pendingCredential,
                        providerLabel: providerLabel,
                        displayName: displayName
                    )
                }
            }
        }
    }

    private func presentCrossProviderLink(email: String, existingMethod: String,
                                          existingLabel: String, newLabel: String,
                                          credential: AuthCredential, displayName: String?) {
        DispatchQueue.main.async {
            self.isLoading = false
            self.crossProviderLink = CrossProviderLink(
                email: email,
                existingProviderLabel: existingLabel,
                newProviderLabel: newLabel,
                existingMethod: existingMethod,
                pendingCredential: credential,
                displayName: displayName
            )
        }
    }

    // MARK: - Re-authentication (for account deletion)

    /// How the signed-in user proves their identity when Firebase demands a
    /// recent login. Social accounts have no password to type.
    enum ReauthMethod {
        case password
        case google
        case apple
    }

    /// Result of an OAuth re-authentication.
    enum ReauthOutcome {
        /// Apple hands back an authorization code that must be used to revoke the
        /// token when deleting the account; Google re-auth carries `nil`.
        case success(appleAuthorizationCode: String?)
        /// User dismissed the provider sheet — not an error worth surfacing.
        case cancelled
        case failure(String)
    }

    /// Intermediate result of asking a provider for a fresh credential.
    private enum CredentialOutcome {
        case credential(AuthCredential, appleAuthorizationCode: String?)
        case cancelled
        case failure(String)
    }

    /// The provider the signed-in user must re-authenticate with.
    ///
    /// OAuth providers are preferred over `password`: an account that was created
    /// with Apple or Google has no password, and asking for one is the bug this
    /// resolves. A user who linked both still gets the one-tap provider sheet.
    static func reauthMethod(for user: FirebaseAuth.User? = Auth.auth().currentUser) -> ReauthMethod {
        let providers = Set((user?.providerData ?? []).map { $0.providerID })
        if providers.contains("apple.com") { return .apple }
        if providers.contains("google.com") { return .google }
        return .password
    }

    /// Whether the account has an email/password credential at all. Accounts created
    /// with Apple or Google don't, so there is no password to enter or change.
    static func hasPasswordProvider(for user: FirebaseAuth.User? = Auth.auth().currentUser) -> Bool {
        (user?.providerData ?? []).contains { $0.providerID == "password" }
    }

    /// Re-authenticate the signed-in user through their OAuth provider. The
    /// completion is always delivered on the main queue.
    func reauthenticateWithProvider(_ method: ReauthMethod,
                                    completion: @escaping (ReauthOutcome) -> Void) {
        guard let authUser = Auth.auth().currentUser else {
            DispatchQueue.main.async { completion(.failure("No authenticated user found")) }
            return
        }

        let handle: (CredentialOutcome) -> Void = { outcome in
            switch outcome {
            case .cancelled:
                DispatchQueue.main.async { completion(.cancelled) }

            case .failure(let message):
                DispatchQueue.main.async { completion(.failure(message)) }

            case .credential(let credential, let appleAuthorizationCode):
                authUser.reauthenticate(with: credential) { _, error in
                    DispatchQueue.main.async {
                        if let error = error {
                            completion(.failure(Self.reauthErrorMessage(error, method: method)))
                        } else {
                            completion(.success(appleAuthorizationCode: appleAuthorizationCode))
                        }
                    }
                }
            }
        }

        switch method {
        case .google:
            requestGoogleCredential(completion: handle)
        case .apple:
            requestAppleCredential(completion: handle)
        case .password:
            // Password accounts re-authenticate through
            // `UserSessionManager.reauthenticateAndDeleteAccount(password:)`.
            DispatchQueue.main.async {
                completion(.failure("This account signs in with a password. Please enter it to continue."))
            }
        }
    }

    /// Ask Google for a fresh credential. Deliberately independent of the sign-in
    /// state machine — no `isLoading`/`isProvisioningProfile` side effects, since
    /// the user is already signed in and no profile is being created.
    private func requestGoogleCredential(completion: @escaping (CredentialOutcome) -> Void) {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            completion(.failure("Google Sign-In is not configured correctly. Please try again later."))
            return
        }

        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)

        guard let presenter = Self.topViewController() else {
            completion(.failure("Unable to present Google Sign-In. Please try again."))
            return
        }

        GIDSignIn.sharedInstance.signIn(withPresenting: presenter) { result, error in
            if let error = error {
                if (error as NSError).code == GIDSignInError.canceled.rawValue {
                    completion(.cancelled)
                } else {
                    completion(.failure("Google Sign-In failed: \(error.localizedDescription)"))
                }
                return
            }

            guard let gidUser = result?.user,
                  let idToken = gidUser.idToken?.tokenString else {
                completion(.failure("Google Sign-In failed: missing credentials. Please try again."))
                return
            }

            completion(.credential(
                GoogleAuthProvider.credential(withIDToken: idToken,
                                              accessToken: gidUser.accessToken.tokenString),
                appleAuthorizationCode: nil
            ))
        }
    }

    /// Ask Apple for a fresh credential plus the authorization code needed to
    /// revoke the token on deletion.
    private func requestAppleCredential(completion: @escaping (CredentialOutcome) -> Void) {
        let nonce = Self.randomNonceString()
        currentNonce = nonce
        appleCredentialCompletion = completion

        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(nonce)

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }

    private static func reauthErrorMessage(_ error: Error, method: ReauthMethod) -> String {
        let label = method == .apple ? "Apple" : "Google"
        switch (error as NSError).code {
        case AuthErrorCode.userMismatch.rawValue:
            return "That \(label) account doesn't match the one you're signed in with. Please try again with the same account."
        case AuthErrorCode.tooManyRequests.rawValue:
            return "Too many attempts. Please wait a few minutes and try again."
        case AuthErrorCode.networkError.rawValue:
            return "Network error. Please check your connection and try again."
        default:
            return "Couldn't verify your \(label) account: \(error.localizedDescription)"
        }
    }

    // MARK: - Firestore profile (no duplicate profiles)

    /// Ensure exactly one Firestore `users` profile exists for this account.
    private func ensureUserDocument(for user: FirebaseAuth.User) {
        guard let email = user.email, !email.isEmpty else {
            self.finish(error: "Your account is missing an email address and can't be set up.")
            return
        }

        db.collection("users")
            .whereField("email", isEqualTo: email)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }

                if let error = error {
                    self.finish(error: "Couldn't load your profile: \(error.localizedDescription)")
                    return
                }

                // Existing profile — just load it. No duplicate created.
                if snapshot?.documents.first != nil {
                    self.loadSessionAndFinish()
                    return
                }

                // No profile yet — this is a first-time social sign-up. Hand off to
                // ProfileSetupView so the user picks their own username and name
                // instead of being handed a generated one. Nothing is written here;
                // the profile is created when they finish setup.
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.errorMessage = ""
                    UserSessionManager.shared.isProvisioningProfile = false
                    UserSessionManager.shared.setProfileStatus(.needsSetup)
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
    /// Used to prefill the username field during profile setup.
    func generateUniqueUsername(seed: String, attempt: Int = 0, completion: @escaping (String) -> Void) {
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
            candidate = "user" + String(UUID().uuidString.prefix(8)).lowercased()
        }

        db.collection("users").document(candidate).getDocument { [weak self] document, error in
            guard let self = self else { return }
            if error != nil || document?.exists == false {
                completion(candidate)
            } else {
                self.generateUniqueUsername(seed: seed, attempt: attempt + 1, completion: completion)
            }
        }
    }

    // MARK: - Helpers

    /// Quietly reset to idle (e.g. user cancelled a provider sheet).
    private func abort() {
        UserSessionManager.shared.isProvisioningProfile = false
        appleLinkAfter = nil
        DispatchQueue.main.async { self.isLoading = false }
    }

    private func finish(error: String) {
        UserSessionManager.shared.isProvisioningProfile = false
        appleLinkAfter = nil
        DispatchQueue.main.async {
            self.isLoading = false
            self.errorMessage = error
        }
    }

    /// Error terminus for the password link sheet — keeps the sheet open and shows
    /// the message inline instead of via the login screen's alert.
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

    private static func keyWindow() -> UIWindow? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
            ?? UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        return scene?.windows.first(where: { $0.isKeyWindow }) ?? scene?.windows.first
    }

    /// Find the top-most view controller to present the Google sign-in sheet from.
    private static func topViewController() -> UIViewController? {
        var top = keyWindow()?.rootViewController
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

// MARK: - ASAuthorizationController delegate (programmatic Apple re-auth)

extension AuthenticationManager: ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {

    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithAuthorization authorization: ASAuthorization) {
        // Re-authentication (account deletion) hands the credential straight back
        // to its caller — no sign-in or profile provisioning involved.
        if let credentialCompletion = appleCredentialCompletion {
            appleCredentialCompletion = nil

            guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                credentialCompletion(.failure("Sign in with Apple failed: unexpected credential."))
                return
            }
            guard let nonce = currentNonce else {
                credentialCompletion(.failure("Sign in with Apple failed: invalid state. Please try again."))
                return
            }
            guard let identityToken = appleIDCredential.identityToken,
                  let idTokenString = String(data: identityToken, encoding: .utf8) else {
                credentialCompletion(.failure("Sign in with Apple failed: unable to read identity token."))
                return
            }

            currentNonce = nil
            let authorizationCode = appleIDCredential.authorizationCode
                .flatMap { String(data: $0, encoding: .utf8) }

            credentialCompletion(.credential(
                OAuthProvider.appleCredential(withIDToken: idTokenString,
                                              rawNonce: nonce,
                                              fullName: appleIDCredential.fullName),
                appleAuthorizationCode: authorizationCode
            ))
            return
        }

        let linkAfter = appleLinkAfter
        appleLinkAfter = nil

        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            self.finish(error: "Sign in with Apple failed: unexpected credential.")
            return
        }
        DispatchQueue.main.async { self.isLoading = true }
        processAppleCredential(appleIDCredential, linkAfter: linkAfter)
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        if let credentialCompletion = appleCredentialCompletion {
            appleCredentialCompletion = nil
            currentNonce = nil
            if let authError = error as? ASAuthorizationError, authError.code == .canceled {
                credentialCompletion(.cancelled)
            } else {
                credentialCompletion(.failure("Sign in with Apple failed: \(error.localizedDescription)"))
            }
            return
        }

        appleLinkAfter = nil
        if let authError = error as? ASAuthorizationError, authError.code == .canceled {
            self.abort()
            return
        }
        self.finish(error: "Sign in with Apple failed: \(error.localizedDescription)")
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return Self.keyWindow() ?? ASPresentationAnchor()
    }
}
