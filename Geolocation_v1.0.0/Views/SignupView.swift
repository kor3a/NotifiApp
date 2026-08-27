//
//  SignupView.swift
//  Quick
//
//  Created by Subong Jeon on 6/22/24.
//

import SwiftUI
import AuthenticationServices

struct SignupView: View {
    var onSignupComplete: ((String) -> Void)? = nil

    @StateObject private var viewModel = SignupViewModel()

    @State private var alertMsg = ""
    @State private var showAlert = false
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                Spacer()
                    .frame(height: 24)

                // The wordmark belongs to the screen this was pushed from; the
                // title here names the job, the way the app's other form sheets
                // do.
                Text("Create your account")
                    .font(OrganicPalette.display(32))
                    .foregroundColor(OrganicPalette.ink(colorScheme))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 4)

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
                        text: $viewModel.userId,
                        prompt: OrganicPalette.prompt("User ID", colorScheme)
                    )
                    .font(OrganicPalette.body(17))
                    .foregroundColor(OrganicPalette.ink(colorScheme))
                    .textContentType(.username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .organicField(colorScheme)

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

                    TextField(
                        "",
                        text: $viewModel.name,
                        prompt: OrganicPalette.prompt("Name", colorScheme)
                    )
                    .font(OrganicPalette.body(17))
                    .foregroundColor(OrganicPalette.ink(colorScheme))
                    .textContentType(.name)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .organicField(colorScheme)

                    SecureField(
                        "",
                        text: $viewModel.password,
                        prompt: OrganicPalette.prompt("Password", colorScheme)
                    )
                    .font(OrganicPalette.body(17))
                    .foregroundColor(OrganicPalette.ink(colorScheme))
                    .textContentType(.newPassword)
                    .organicField(colorScheme)

                    SecureField(
                        "",
                        text: $viewModel.confirmPassword,
                        prompt: OrganicPalette.prompt("Confirm Password", colorScheme)
                    )
                    .font(OrganicPalette.body(17))
                    .foregroundColor(OrganicPalette.ink(colorScheme))
                    .textContentType(.newPassword)
                    .organicField(colorScheme)
                }
                .padding(.horizontal, 20)

                OrganicPillButton(
                    title: "Sign Up",
                    isLoading: viewModel.isLoading,
                    fillsWidth: true
                ) {
                    viewModel.register()
                }
                .disabled(viewModel.isLoading)
                .padding(.horizontal, 20)
                .padding(.top, 4)

                Spacer()

            }//:VSTACK
        }//:SCROLLVIEW
        .background(
            OrganicPalette.canvas(colorScheme)
                .ignoresSafeArea()
        )
        // Pushed onto LoginView's stack, so the back chevron is this screen's
        // to tint.
        .toolbarBackground(OrganicPalette.canvas(colorScheme), for: .navigationBar)
        .tint(OrganicPalette.terracotta(colorScheme))
        .alert(isPresented: $showAlert) {
            Alert(title: Text("Note"), message: Text(alertMsg), dismissButton: .default(Text("OK")))
        }
        .onReceive(viewModel.$errorMessage, perform: { errorMessage in
            if !errorMessage.isEmpty {
                alertMsg = errorMessage
                showAlert = true
            }
        })
        .onChange(of: viewModel.signupComplete) { complete in
            if complete {
                onSignupComplete?(viewModel.email.lowercased())
            }
        }
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
