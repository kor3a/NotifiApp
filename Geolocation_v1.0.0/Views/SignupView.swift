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
    
    var body: some View {
        VStack {
            Text("Sign Up")
                .padding()
                .font(.largeTitle)
                .fontWeight(.bold)
                
            
            if viewModel.errorMessage.isEmpty {
                Text(viewModel.errorMessage)
            }
            
            TextField("User ID", text: $viewModel.userId)
                .padding()
            
            TextField("Email", text: $viewModel.email)
                .padding()
            
            TextField("Name", text: $viewModel.name)
                .padding()
            
            SecureField("Password", text: $viewModel.password)
                .padding()
            
            SecureField("Confirm Password", text: $viewModel.confirmPassword)
                .padding()
            
            Button(action: {
                viewModel.register()
            }) {
                Text("Sign Up")
                    .font(.headline)
                    .padding()
                    .foregroundColor(.black)
                    .background(Color.green)
                    .frame(height: 25)
                    .cornerRadius(100)
            }//:BUTTON
            .padding()
            
            
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
