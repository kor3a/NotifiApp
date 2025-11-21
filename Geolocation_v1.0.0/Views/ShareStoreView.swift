//
//  ShareStoreView.swift
//  Geolocation_v1.0.0
//
//  Created by Claude on 11/21/24.
//

import SwiftUI

struct ShareStoreView: View {
    // MARK: - PROPERTIES

    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var viewModel: StoresViewModel
    let userStoreItem: UserStoreItem

    @State private var recipientEmail: String = ""
    @State private var selectedPermission: StorePermission = .edit
    @State private var isSharing: Bool = false
    @State private var showAlert: Bool = false
    @State private var alertMessage: String = ""
    @State private var alertTitle: String = ""

    // MARK: - BODY

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Store Info
                VStack(alignment: .leading, spacing: 8) {
                    Text("Sharing Store")
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    HStack {
                        Image(systemName: "cart.fill")
                            .foregroundStyle(.blue)
                            .font(.title2)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(userStoreItem.store.name)
                                .font(.title3)
                                .bold()

                            Text(userStoreItem.store.address)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                    )
                }

                // Email Input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recipient's Email")
                        .font(.headline)

                    TextField("Enter email address", text: $recipientEmail)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(colorScheme == .dark ? Color(white: 0.15) : Color.white)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                        )
                }

                // Permission Selection
                VStack(alignment: .leading, spacing: 8) {
                    Text("Permission")
                        .font(.headline)

                    Picker("Permission", selection: $selectedPermission) {
                        Text("Can Edit").tag(StorePermission.edit)
                        Text("View Only").tag(StorePermission.view)
                    }
                    .pickerStyle(.segmented)

                    // Permission description
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: selectedPermission == .edit ? "pencil.circle.fill" : "eye.circle.fill")
                            .foregroundStyle(selectedPermission == .edit ? .green : .orange)

                        Text(selectedPermission == .edit
                            ? "Can Edit: Recipient gets full ownership. Changes and deletions sync between both users."
                            : "View Only: Recipient can view reminders but cannot edit, share, delete, or check them off.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill((selectedPermission == .edit ? Color.green : Color.orange).opacity(0.1))
                    )
                }

                // Info Text
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(.blue)

                    Text("The store and all its active reminders will be shared. The recipient must have an account with the email address you provide.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.blue.opacity(0.1))
                )

                Spacer()

                // Share Button
                Button(action: shareStore) {
                    if isSharing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Share Store")
                                .bold()
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                    }
                }
                .disabled(recipientEmail.isEmpty || isSharing)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(recipientEmail.isEmpty || isSharing ? Color.gray : Color.blue)
                )
                .foregroundColor(.white)
            }
            .padding()
            .navigationTitle("Share Store")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert(alertTitle, isPresented: $showAlert) {
                Button("OK") {
                    if alertTitle == "Success" {
                        dismiss()
                    }
                }
            } message: {
                Text(alertMessage)
            }
        }
    }

    // MARK: - FUNCTIONS

    private func shareStore() {
        // Validate email format
        guard isValidEmail(recipientEmail) else {
            alertTitle = "Invalid Email"
            alertMessage = "Please enter a valid email address."
            showAlert = true
            return
        }

        isSharing = true

        viewModel.shareStore(
            userStoreItem: userStoreItem,
            recipientEmail: recipientEmail.lowercased().trimmingCharacters(in: .whitespaces),
            permission: selectedPermission
        ) { success, message in
            isSharing = false

            if success {
                alertTitle = "Success"
                alertMessage = message ?? "Store shared successfully!"
            } else {
                alertTitle = "Error"
                alertMessage = message ?? "Failed to share store. Please try again."
            }

            showAlert = true
        }
    }

    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
}

#Preview {
    ShareStoreView(
        viewModel: StoresViewModel(),
        userStoreItem: UserStoreItem(
            id: "preview-id",
            store: Store(
                id: "store-id",
                name: "Target",
                address: "123 Main St, City, ST 12345",
                reminderCount: 3
            ),
            permission: .owner,
            sharedStoreGroupId: nil
        )
    )
}
