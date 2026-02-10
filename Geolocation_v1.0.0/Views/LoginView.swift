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
    @State private var errorMessage: String = ""
    @State private var showAlert: Bool = false
    @State private var isSignup: Bool = false
    @State private var isForgotPassword: Bool = false
    @State private var currentNonce: String?
    @Environment(\.colorScheme) var colorScheme

    @StateObject private var viewModel = LoginViewModel()

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
                    }
                    .buttonStyle(PrimaryButtonStyle(color: .green))
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                    /*
                    Text("Or")
                        .font(.footnote)
                        .frame(height:5)

                    // Only works with Apple Developer account ($99/yr)
                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = [.email, .fullName]
                    } onCompletion: { result in
                        switch result {
                        case .success(let authorization):
                            loginWithFirebase(authorization)
                        case .failure(let error):
                            showError(error.localizedDescription)
                        }
                    }
                    .frame(width: 150, height: 36)
                    .clipShape(.capsule)
                    .padding(.top, 10)
                    */

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
            .navigationDestination(isPresented: $isSignup) { SignupView() }
            .navigationDestination(isPresented: $isForgotPassword) { ForgotPasswordView() }
        }//:NAVIGATIONVIEW

    }//:BODY
    
    
    /// Presenting error message alert
    func showError(_ message: String){
        errorMessage = message
        showAlert.toggle()
    }
    
    /// Login with Firebase with Apple
    func loginWithFirebase(_ authorization: ASAuthorization) {
        if let userCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            print(userCredential.user)
            
            if userCredential.authorizedScopes.contains(.fullName) {
                print(userCredential.fullName?.givenName ?? "No given name")
            }
            
            if userCredential.authorizedScopes.contains(.email) {
                print(userCredential.email ?? "No email")
            }
            
        }
    }
    
    func forgotPasswordTapped() {
        isForgotPassword.toggle()
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
