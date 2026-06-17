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
    @StateObject private var authManager = AuthenticationManager()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Spacer()
                        .frame(height: 40)

                    Text("Allim")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .padding(.bottom, 8)

                    if showSignupConfirmation {
                        VStack(spacing: 8) {
                            Image(systemName: "envelope.badge.shield.half.filled")
                                .font(.system(size: 36))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.blue, .purple],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )

                            Text("A confirmation email has been sent to \(signupConfirmationEmail). Please click on the link to complete the sign up.")
                                .font(.subheadline)
                                .multilineTextAlignment(.center)
                                .foregroundColor(.secondary)

                            Text("Can't find it? Be sure to check your spam or junk folder.")
                                .font(.caption)
                                .multilineTextAlignment(.center)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(
                                            LinearGradient(
                                                colors: [.blue, .purple],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            ),
                                            lineWidth: 1
                                        )
                                )
                        )
                        .padding(.horizontal, 20)
                    }

                    if !viewModel.errorMessage.isEmpty {
                        Text(viewModel.errorMessage)
                            .foregroundStyle(.red)
                            .font(.caption)
                            .padding(.horizontal)
                            .multilineTextAlignment(.center)
                    }

                    VStack(spacing: 16) {
                        TextField("Email", text: $viewModel.email)
                            .textFieldStyle(.plain)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.cardBorder(for: colorScheme), lineWidth: 1.5)
                                    )
                            )

                        SecureField("Password", text: $viewModel.password)
                            .textFieldStyle(.plain)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.cardBorder(for: colorScheme), lineWidth: 1.5)
                                    )
                            )
                    }
                    .padding(.horizontal, 20)

                    Button(action: {
                        viewModel.login()
                    }) {
                        Text("Login")
                            .font(.headline)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(
                                                LinearGradient(
                                                    colors: [.blue, .purple],
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                ),
                                                lineWidth: 1.5
                                            )
                                    )
                            )
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                    socialSignInSection

                    if viewModel.showEmailNotVerified {
                        Button(action: {
                            viewModel.resendVerificationEmail()
                        }) {
                            Text(viewModel.isResendingVerification ? "Sending..." : "Resend Verification Email")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.blue)
                                .underline()
                        }
                        .disabled(viewModel.isResendingVerification)
                        .padding(.top, 4)
                    }

                    Button(action: {
                        isSignup.toggle()
                    }) {
                        Text("Don't have an account? Sign up here.")
                            .font(.system(size: 12))
                            .underline()
                    }
                    .padding(.top, 12)

                    HStack(spacing: 4) {
                        Text("Forgot password?")
                            .font(.system(size: 12))

                        Text("Click here")
                            .font(.system(size: 12))
                            .foregroundColor(.blue)
                            .underline()
                            .onTapGesture {
                                forgotPasswordTapped()
                            }
                    }
                    .padding(.top, 8)

                    Spacer()

                }//:VSTACK
            }//:SCROLLVIEW
            .background(
                Color.backgroundGradient(for: colorScheme)
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
                }
            })
            .overlay {
                if authManager.isLoading {
                    ZStack {
                        Color.black.opacity(0.25).ignoresSafeArea()
                        ProgressView()
                            .padding(24)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            .sheet(item: $authManager.pendingLink) { link in
                LinkAccountSheet(authManager: authManager, link: link)
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

    /// "or" divider plus the Google and Apple sign-in buttons, shown beneath the
    /// email/password Login button. Both routes flow through AuthenticationManager,
    /// which dedupes against existing Firebase Auth and Firestore accounts.
    private var socialSignInSection: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                Rectangle()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(height: 1)
                Text("or")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                Rectangle()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(height: 1)
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)

            // Continue with Google
            Button(action: {
                authManager.signInWithGoogle()
            }) {
                HStack(spacing: 10) {
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
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.cardBorder(for: colorScheme), lineWidth: 1.5)
                        )
                )
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
            .frame(height: 50)
            .clipShape(RoundedRectangle(cornerRadius: 10))
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
            VStack(spacing: 20) {
                Image(systemName: "link.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(
                        LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing)
                    )
                    .padding(.top, 24)

                Text("Link your account")
                    .font(.title3.bold())

                Text("You already have an account for \(link.email). Enter your password to connect \(link.providerLabel) to it — no duplicate account will be created.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                SecureField("Password", text: $password)
                    .textFieldStyle(.plain)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.cardBorder(for: colorScheme), lineWidth: 1.5)
                            )
                    )
                    .padding(.horizontal)

                if !authManager.linkErrorMessage.isEmpty {
                    Text(authManager.linkErrorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Button(action: {
                    authManager.completeLinkWithPassword(password)
                }) {
                    ZStack {
                        Text("Link & Continue")
                            .font(.headline)
                            .foregroundColor(.white)
                            .opacity(authManager.isLoading ? 0 : 1)
                        if authManager.isLoading {
                            ProgressView().tint(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(
                                LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing)
                            )
                    )
                }
                .disabled(password.isEmpty || authManager.isLoading)
                .padding(.horizontal)

                Spacer()
            }
            .interactiveDismissDisabled(authManager.isLoading)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        authManager.cancelPendingLink()
                    }
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
