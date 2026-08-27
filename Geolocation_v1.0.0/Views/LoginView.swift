//
//  LoginView.swift
//  Quick
//
//  Created by Subong Jeon on 6/19/24.
//

import SwiftUI
import AuthenticationServices
import Firebase
import FirebaseAuth
import CryptoKit

struct LoginView: View {
    @State private var alertMsg: String = ""
    @State private var showAlert: Bool = false
    @State private var isSignup: Bool = false
    @State private var isForgotPassword: Bool = false
    @State private var showSignupConfirmation: Bool = false
    @State private var signupConfirmationEmail: String = ""
    @Environment(\.colorScheme) var colorScheme

    @StateObject private var viewModel = LoginViewModel()
    // Use the shared instance (not a view-owned one): provisioning a brand-new
    // social profile continues after LoginView is torn down on successful sign-in.
    @ObservedObject private var authManager = AuthenticationManager.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    Spacer()
                        .frame(height: 32)

                    wordmark

                    if showSignupConfirmation {
                        VStack(spacing: 10) {
                            Image(systemName: "envelope.badge.shield.half.filled")
                                .font(.system(size: 30, weight: .semibold))
                                .foregroundColor(OrganicPalette.sageInk(colorScheme))

                            Text("A confirmation email has been sent to \(signupConfirmationEmail). Please click on the link to complete the sign up.")
                                .font(OrganicPalette.body(15))
                                .foregroundColor(OrganicPalette.sageInk(colorScheme))
                                .multilineTextAlignment(.center)

                            Text("Can't find it? Be sure to check your spam or junk folder.")
                                .font(OrganicPalette.body(13))
                                .foregroundColor(OrganicPalette.sageInk(colorScheme).opacity(0.8))
                                .multilineTextAlignment(.center)
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .fill(OrganicPalette.sage(colorScheme))
                        )
                        .padding(.horizontal, 20)
                    }

                    if !viewModel.errorMessage.isEmpty {
                        Text(viewModel.errorMessage)
                            .font(OrganicPalette.body(13))
                            .foregroundColor(OrganicPalette.rust(colorScheme))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }

                    VStack(spacing: 12) {
                        TextField(
                            "",
                            text: $viewModel.email,
                            prompt: OrganicPalette.prompt("Email", colorScheme)
                        )
                        .font(OrganicPalette.body(17))
                        .foregroundColor(OrganicPalette.ink(colorScheme))
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .organicField(colorScheme)

                        SecureField(
                            "",
                            text: $viewModel.password,
                            prompt: OrganicPalette.prompt("Password", colorScheme)
                        )
                        .font(OrganicPalette.body(17))
                        .foregroundColor(OrganicPalette.ink(colorScheme))
                        .textContentType(.password)
                        .organicField(colorScheme)
                    }
                    .padding(.horizontal, 20)

                    OrganicPillButton(title: "Login", fillsWidth: true) {
                        viewModel.login()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 4)

                    socialSignInSection

                    if viewModel.showEmailNotVerified {
                        Button(action: {
                            viewModel.resendVerificationEmail()
                        }) {
                            Text(viewModel.isResendingVerification ? "Sending\u{2026}" : "Resend verification email")
                                .font(OrganicPalette.title(14))
                                .foregroundColor(OrganicPalette.terracotta(colorScheme))
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.isResendingVerification)
                        .padding(.top, 4)
                    }

                    // The two ways off this screen, as quiet text rather than a
                    // second and third pill — Login is the only thing here that
                    // should read as a button.
                    VStack(spacing: 12) {
                        Button(action: {
                            isSignup.toggle()
                        }) {
                            HStack(spacing: 5) {
                                Text("Don't have an account?")
                                    .font(OrganicPalette.body(14))
                                    .foregroundColor(OrganicPalette.inkSoft(colorScheme))
                                Text("Sign up")
                                    .font(OrganicPalette.title(14))
                                    .foregroundColor(OrganicPalette.terracotta(colorScheme))
                            }
                        }
                        .buttonStyle(.plain)

                        Button(action: forgotPasswordTapped) {
                            Text("Forgot password?")
                                .font(OrganicPalette.body(14))
                                .foregroundColor(OrganicPalette.inkSoft(colorScheme))
                                .underline()
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 10)

                    Spacer()

                }//:VSTACK
            }//:SCROLLVIEW
            .background(
                OrganicPalette.canvas(colorScheme)
                    .ignoresSafeArea()
            )
            .alert(isPresented: $showAlert) {
                Alert(title: Text("Note"), message: Text(alertMsg), dismissButton: .default(Text("OK")))
            }
            .onReceive(viewModel.$errorMessage, perform: { errorMessage in
                if !errorMessage.isEmpty {
                    alertMsg = errorMessage
                    showAlert = true
                }
            })
            .onReceive(authManager.$errorMessage, perform: { errorMessage in
                if !errorMessage.isEmpty {
                    alertMsg = errorMessage
                    showAlert = true
                    // Reset so the (now-singleton) manager doesn't re-alert when
                    // LoginView reappears after a later sign-out.
                    authManager.errorMessage = ""
                }
            })
            .overlay {
                if authManager.isLoading {
                    ZStack {
                        OrganicPalette.canvas(colorScheme).opacity(0.7).ignoresSafeArea()
                        ProgressView()
                            .tint(OrganicPalette.terracotta(colorScheme))
                            .padding(28)
                            .background(OrganicCardBackground(colorScheme: colorScheme))
                    }
                }
            }
            .sheet(item: $authManager.pendingLink) { link in
                LinkAccountSheet(authManager: authManager, link: link)
            }
            .alert(
                "Link your accounts?",
                isPresented: Binding(
                    get: { authManager.crossProviderLink != nil },
                    set: { _ in } // dismissal is driven by the buttons below
                ),
                presenting: authManager.crossProviderLink
            ) { link in
                Button("Continue with \(link.existingProviderLabel)") {
                    authManager.confirmCrossProviderLink()
                }
                Button("Cancel", role: .cancel) {
                    authManager.cancelCrossProviderLink()
                }
            } message: { link in
                Text("\(link.email) is already registered with \(link.existingProviderLabel). Sign in with \(link.existingProviderLabel) to link your \(link.newProviderLabel) account — no duplicate account will be created.")
            }
            .navigationDestination(isPresented: $isSignup) {
                SignupView(onSignupComplete: { email in
                    signupConfirmationEmail = email
                    isSignup = false
                    showSignupConfirmation = true
                })
            }
            .navigationDestination(isPresented: $isForgotPassword) { ForgotPasswordView() }
        }//:NAVIGATIONVIEW

    }//:BODY

    /// The app's own mark on a blush disc, with the name below.
    ///
    /// `AllimMark` is the app icon's artwork recoloured into the palette —
    /// terracotta storefront, the badge in sage — and carries light and dark
    /// variants, so the disc behind it and the mark on it change scheme
    /// together. Its ground is transparent because the disc is the ground.
    private var wordmark: some View {
        VStack(spacing: 14) {
            Image("AllimMark")
                .resizable()
                .scaledToFit()
                .frame(width: 86, height: 86)
                .frame(width: 96, height: 96)
                .background(Circle().fill(OrganicPalette.blush(colorScheme)))
                .accessibilityHidden(true)

            Text("Allim")
                .font(OrganicPalette.display(40))
                .foregroundColor(OrganicPalette.ink(colorScheme))
        }
        .padding(.bottom, 4)
    }

    /// "or" divider plus the Google and Apple sign-in buttons, shown beneath the
    /// email/password Login button. Both routes flow through AuthenticationManager,
    /// which dedupes against existing Firebase Auth and Firestore accounts.
    private var socialSignInSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Rectangle()
                    .fill(OrganicPalette.outline(colorScheme))
                    .frame(height: 1)
                Text("or")
                    .font(OrganicPalette.body(14))
                    .foregroundColor(OrganicPalette.inkSoft(colorScheme))
                Rectangle()
                    .fill(OrganicPalette.outline(colorScheme))
                    .frame(height: 1)
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)

            // Continue with Google
            Button(action: {
                authManager.signInWithGoogle()
            }) {
                HStack(spacing: 10) {
                    // Google's own four colours, left alone: it is their mark,
                    // not ours to repaint in terracotta.
                    Text("G")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .red, .yellow, .green],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    Text("Continue with Google")
                        .font(OrganicPalette.title(16))
                        .foregroundColor(OrganicPalette.ink(colorScheme))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(Capsule().fill(OrganicPalette.surface(colorScheme)))
                .overlay(Capsule().stroke(OrganicPalette.outline(colorScheme), lineWidth: 1.5))
            }
            .disabled(authManager.isLoading)
            .padding(.horizontal, 20)

            // Sign in with Apple
            SignInWithAppleButton(.continue) { request in
                authManager.configureAppleRequest(request)
            } onCompletion: { result in
                authManager.handleAppleCompletion(result)
            }
            .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
            .frame(height: 54)
            // Apple draws this button itself, so only its shape is ours to set —
            // a capsule, to sit level with the pills above it.
            .clipShape(Capsule())
            .disabled(authManager.isLoading)
            .padding(.horizontal, 20)
        }
        .padding(.top, 4)
    }

    func forgotPasswordTapped() {
        isForgotPassword.toggle()
    }

}

/// Password prompt shown when a Google/Apple email already belongs to an existing
/// email/password account. Confirming the password lets us LINK the social
/// provider onto that same account instead of creating a duplicate.
private struct LinkAccountSheet: View {
    @ObservedObject var authManager: AuthenticationManager
    let link: AuthenticationManager.PendingLink

    @State private var password: String = ""
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack {
            ZStack {
                OrganicPalette.canvas(colorScheme)
                    .ignoresSafeArea()

                VStack(spacing: 20) {
                    Image(systemName: "link")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundColor(OrganicPalette.terracotta(colorScheme))
                        .frame(width: 88, height: 88)
                        .background(Circle().fill(OrganicPalette.blush(colorScheme)))
                        .padding(.top, 24)

                    Text("Link your account")
                        .font(OrganicPalette.display(26))
                        .foregroundColor(OrganicPalette.ink(colorScheme))

                    Text("You already have an account for \(link.email). Enter your password to connect \(link.providerLabel) to it — no duplicate account will be created.")
                        .font(OrganicPalette.body(15))
                        .foregroundColor(OrganicPalette.inkSoft(colorScheme))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)

                    SecureField(
                        "",
                        text: $password,
                        prompt: Text("Password")
                            .foregroundColor(OrganicPalette.inkSoft(colorScheme).opacity(0.8))
                    )
                    .font(OrganicPalette.body(17))
                    .foregroundColor(OrganicPalette.ink(colorScheme))
                    .textContentType(.password)
                    .organicField(colorScheme)
                    .padding(.horizontal, 24)

                    if !authManager.linkErrorMessage.isEmpty {
                        Text(authManager.linkErrorMessage)
                            .font(OrganicPalette.body(13))
                            .foregroundColor(OrganicPalette.rust(colorScheme))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }

                    OrganicPillButton(
                        title: "Link & Continue",
                        isLoading: authManager.isLoading,
                        fillsWidth: true
                    ) {
                        authManager.completeLinkWithPassword(password)
                    }
                    .disabled(password.isEmpty || authManager.isLoading)
                    .padding(.horizontal, 24)

                    Spacer()
                }
            }
            .interactiveDismissDisabled(authManager.isLoading)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(OrganicPalette.canvas(colorScheme), for: .navigationBar)
            .tint(OrganicPalette.terracotta(colorScheme))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        authManager.cancelPendingLink()
                    }
                    .foregroundColor(OrganicPalette.terracotta(colorScheme))
                    .disabled(authManager.isLoading)
                }
            }
        }
    }
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.1 : 1.0)
            .opacity(configuration.isPressed ? 0.1 : 1.0)
            .animation(.spring(duration: 5), value: configuration.isPressed)
    }
}

#Preview {
    LoginView()
}
