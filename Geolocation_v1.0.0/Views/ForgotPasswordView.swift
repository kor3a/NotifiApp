//
//  ForgotPasswordView.swift
//  Geolocation_v1.0.0
//
//  Created by Claude on 11/17/25.
//

import SwiftUI

struct ForgotPasswordView: View {
    @StateObject private var viewModel = ForgotPasswordViewModel()
    @State private var showAlert: Bool = false
    @State private var alertMsg: String = ""
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer()
                    .frame(height: 40)

                Text("Forgot Password")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.bottom, 8)

                Text("Enter your email address and we'll send you instructions to reset your password.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)

                if !viewModel.errorMessage.isEmpty {
                    Text(viewModel.errorMessage)
                        .foregroundStyle(.red)
                        .font(.caption)
                        .padding(.horizontal)
                        .multilineTextAlignment(.center)
                }

                if !viewModel.successMessage.isEmpty {
                    Text(viewModel.successMessage)
                        .foregroundStyle(.green)
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
                        .autocapitalization(.none)
                        .keyboardType(.emailAddress)
                }
                .padding(.horizontal, 20)

                Button(action: {
                    viewModel.sendPasswordReset()
                }) {
                    if viewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Send Reset Email")
                    }
                }
                .buttonStyle(PrimaryButtonStyle(color: .green))
                .disabled(viewModel.isLoading)
                .padding(.horizontal, 20)
                .padding(.top, 8)

                Button(action: {
                    dismiss()
                }) {
                    Text("Back to Login")
                        .font(.system(size: 12))
                        .underline()
                }
                .padding(.top, 12)

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
        .onReceive(viewModel.$successMessage, perform: { successMessage in
            if !successMessage.isEmpty {
                alertMsg = successMessage
                showAlert = true
            }
        })
    }//:BODY
}

#Preview {
    ForgotPasswordView()
}
