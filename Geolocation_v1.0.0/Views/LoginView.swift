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
    @State private var currentNonce: String?
    
    @StateObject private var viewModel = LoginViewModel()
    
    var body: some View {
        NavigationStack {
            VStack {
                Text("Login")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                if viewModel.errorMessage.isEmpty {
                    Text(viewModel.errorMessage)
                }
                
                TextField("Username", text: $viewModel.email)
                    .padding()
                
                SecureField("Password", text: $viewModel.password)
                    .padding()
                
                Button(action: {
                    viewModel.login()
                }) {
                    Text("Login")
                        .font(.headline)
                        .padding()
                        .foregroundColor(.black)
                        .background(Color.green)
                        .frame(height: 25)
                        .cornerRadius(100)
                }//:BUTTON
                .padding()
                
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
                .padding(.top)
                .padding(.bottom, 10)
                
                
                HStack {
                    Text("Forgot password?")
                        .font(.system(size: 12))
                    
                    Text("Click here")
                        .font(.system(size: 12))
                        .foregroundColor(.blue)
                        .underline()
                        .onTapGesture {
                            forgotPasswordTapped()
                        }
                }//:HSTACK
                
            }//:VSTACK
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
        print("Forgot password tapped")
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
