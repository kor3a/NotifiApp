//
//  AccountSecurityView.swift
//  Geolocation_v1.0.0
//

import SwiftUI

struct AccountSecurityView: View {

    @ObservedObject var viewModel: ProfileViewModel

    var body: some View {
        Form {
            Section(header: Text("Display Name")) {
                TextField("Enter your name", text: $viewModel.newName)
                    .autocapitalization(.words)
                    .disableAutocorrection(true)
            }

            Section(header: Text("Change Password"), footer: Text("Leave blank to keep your current password.")) {
                SecureField("New password", text: $viewModel.newPassword)
                SecureField("Confirm new password", text: $viewModel.confirmPassword)
            }

            Section {
                Button("Save Changes") {
                    viewModel.saveProfileChanges()
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .foregroundStyle(.blue)
                .disabled(viewModel.isLoading)
            }
        }
        .navigationTitle("Account Security")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if viewModel.isLoading {
                ProgressView()
                    .scaleEffect(1.5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.1))
            }
        }
        .safeAreaInset(edge: .top) {
            if !viewModel.successMessage.isEmpty || !viewModel.errorMessage.isEmpty {
                HStack {
                    Image(systemName: !viewModel.successMessage.isEmpty ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    Text(!viewModel.successMessage.isEmpty ? viewModel.successMessage : viewModel.errorMessage)
                        .font(.subheadline)
                }
                .foregroundStyle(!viewModel.successMessage.isEmpty ? .green : .red)
                .padding(.horizontal)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(
                    (!viewModel.successMessage.isEmpty ? Color.green : Color.red)
                        .opacity(0.1)
                )
            }
        }
    }
}
