//
//  SignupView.swift
//  Quick
//
//  Created by Subong Jeon on 6/22/24.
//

import SwiftUI
import AuthenticationServices

struct SignupView: View {
    @StateObject private var viewModel = SignupViewModel()

    @State private var alertMsg = ""
    @State private var showAlert = false
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss

    var body: some View {
        if viewModel.signupComplete {
            emailConfirmationView
        } else {
            signupFormView
        }
    }

    // MARK: - Email Confirmation View
    private var emailConfirmationView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "envelope.badge.shield.half.filled")
                .font(.system(size: 60))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )

            Text("Verify Your Email")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )

            Text("We've sent a confirmation email to:")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text(viewModel.email.lowercased())
                .font(.subheadline)
                .fontWeight(.semibold)

            Text("Please check your inbox and tap the verification link to complete your sign up. Then come back and log in.")
                .font(.footnote)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button(action: {
                dismiss()
            }) {
                Text("Back to Login")
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

            Spacer()
        }
        .background(
            Color.backgroundGradient(for: colorScheme)
                .ignoresSafeArea()
        )
    }

    // MARK: - Signup Form View
    private var signupFormView: some View {
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

                if !viewModel.errorMessage.isEmpty {
                    Text(viewModel.errorMessage)
                        .foregroundStyle(.red)
                        .font(.caption)
                        .padding(.horizontal)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 16) {
                    TextField("User ID", text: $viewModel.userId)
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

                    TextField("Name", text: $viewModel.name)
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

                    SecureField("Confirm Password", text: $viewModel.confirmPassword)
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
                    viewModel.register()
                }) {
                    Text("Sign Up")
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
    }
    
    
    private func configure(_ request: ASAuthorizationAppleIDRequest) {
        request.requestedScopes = [.fullName, .email]
    }
    
    private func handle(_ result: Result<ASAuthorization, Error>) {
        switch result {
            case .success(let auth):
                switch auth.credential {
                case let appleIDCredential as ASAuthorizationAppleIDCredential:
                    let userIdentifier = appleIDCredential.user
                    let fullName = appleIDCredential.fullName
                    let email = appleIDCredential.email
                
                    
                    //handle the successful sign in with Apple here. e.g., save userIdentifier, fullName, and email to my backend
                    
            default:
                break
            }
            case .failure(let error):
                alertMsg = "Sign Up with Apple failed: \(error.localizedDescription)"
                showAlert = true
            }
        }
    
}

#Preview {
    SignupView()
}
