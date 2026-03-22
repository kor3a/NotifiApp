//
//  ProfileView.swift
//  Geolocation_v1.0.0
//
//  Created by Subong Jeon on 8/5/24.
//

import SwiftUI
import FirebaseAuth

struct ProfileView: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = ProfileViewModel()
    @ObservedObject private var sessionManager = UserSessionManager.shared
    @State private var showImagePicker = false
    @State private var selectedImage: UIImage?
    @State private var showDeleteAccountAlert = false
    @State private var reauthPassword = ""

    var body: some View {
        if sessionManager.isLoading || viewModel.isLoading {
            VStack {
                ProgressView()
                    .scaleEffect(1.5)
                    .padding()
                Text("Loading profile...")
                    .foregroundStyle(.gray)
            }
        } else if let user = viewModel.user {
            profileEditView(user: user)
        } else {
            VStack {
                Image(systemName: "exclamationmark.triangle")
                    .resizable()
                    .frame(width: 50, height: 50)
                    .foregroundStyle(.red)
                    .padding()
                Text(!sessionManager.errorMessage.isEmpty ? sessionManager.errorMessage : "No user data available")
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding()
                Button("Retry") {
                    sessionManager.fetchUser()
                }
                .padding()
                Button("Sign Out") {
                    viewModel.signOut()
                }
                .foregroundStyle(.red)
            }
            .padding()
        }
    }

    @ViewBuilder
    func profileEditView(user: User) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                // Profile Picture and Info Section
                HStack(alignment: .top, spacing: 20) {
                    // Profile Picture
                    Button {
                        showImagePicker = true
                    } label: {
                        if let selectedImage = selectedImage {
                            Image(uiImage: selectedImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 80, height: 80)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.blue, lineWidth: 2))
                        } else if let profilePictureURL = user.profilePictureURL,
                                  let url = URL(string: profilePictureURL) {
                            AsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 80, height: 80)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(Color.blue, lineWidth: 2))
                            } placeholder: {
                                Image(systemName: "person.circle.fill")
                                    .resizable()
                                    .frame(width: 80, height: 80)
                                    .foregroundStyle(.gray)
                            }
                        } else {
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .frame(width: 80, height: 80)
                                .foregroundStyle(.gray)
                        }
                    }
                    .sheet(isPresented: $showImagePicker) {
                        ImagePicker(selectedImage: $selectedImage, onImageSelected: { image in
                            viewModel.uploadProfilePicture(image: image)
                            // Clear selected image after 2 seconds to show the uploaded image from URL
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                selectedImage = nil
                            }
                        })
                    }

                    // Name and Email
                    VStack(alignment: .leading, spacing: 8) {
                        Text(user.name)
                            .font(.title2)
                            .bold()

                        Text("@\(user.userId)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Text(user.email)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 8)

                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 20)

                // Success Message
                if !viewModel.successMessage.isEmpty {
                    Text(viewModel.successMessage)
                        .foregroundStyle(.green)
                        .font(.subheadline)
                        .padding(.horizontal)
                }

                // Error Message
                if !viewModel.errorMessage.isEmpty {
                    Text(viewModel.errorMessage)
                        .foregroundStyle(.red)
                        .font(.subheadline)
                        .padding(.horizontal)
                }

                // Edit Fields Section
                VStack(spacing: 16) {
                    // Name Field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Name")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        TextField("Enter your name", text: $viewModel.newName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocapitalization(.words)
                            .disableAutocorrection(true)
                            .id("nameTextField")
                    }

                    // New Password Field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("New Password (optional)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        SecureField("Enter new password", text: $viewModel.newPassword)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }

                    // Confirm Password Field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Confirm Password")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        SecureField("Confirm new password", text: $viewModel.confirmPassword)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                }
                .padding(.horizontal)
                .padding(.top, 10)

                // Save Button
                Button("Save Changes") {
                    viewModel.saveProfileChanges()
                }
                .buttonStyle(PrimaryButtonStyle(color: .blue))
                .padding(.horizontal)
                .padding(.top, 20)

                // Sign Out Button
                Button("Sign Out") {
                    viewModel.signOut()
                }
                .buttonStyle(SecondaryButtonStyle(color: .red))
                .padding(.horizontal)
                .padding(.top, 10)

                // Delete Account Button
                Button("Delete Account") {
                    showDeleteAccountAlert = true
                }
                .buttonStyle(SecondaryButtonStyle(color: .red))
                .padding(.horizontal)
                .padding(.top, 4)
                .alert("Delete Account", isPresented: $showDeleteAccountAlert) {
                    Button("Delete", role: .destructive) {
                        viewModel.deleteAccount()
                    }
                    Button("Cancel", role: .cancel) { }
                } message: {
                    Text("This will permanently delete your account and all associated data. This action cannot be undone.")
                }
                .alert("Confirm Your Identity", isPresented: $viewModel.needsReauthForDeletion) {
                    SecureField("Password", text: $reauthPassword)
                    Button("Delete Account", role: .destructive) {
                        let password = reauthPassword
                        reauthPassword = ""
                        viewModel.reauthenticateAndDelete(password: password)
                    }
                    Button("Cancel", role: .cancel) {
                        reauthPassword = ""
                    }
                } message: {
                    Text("Please enter your password to confirm account deletion.")
                }

                #if DEBUG
                Button("Replay Tutorial") {
                    TutorialManager.shared.resetTutorial()
                    dismiss()
                    TutorialManager.shared.pendingTabSwitch = 0
                    if let userId = sessionManager.currentUser?.userId {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            TutorialManager.shared.startIfNeeded(userId: userId)
                        }
                    }
                }
                .buttonStyle(SecondaryButtonStyle(color: .orange))
                .padding(.horizontal)
                .padding(.top, 4)
                #endif

                Spacer().frame(height: 30)
            }
        }
        .onAppear {
            // Initialize the name field only if it's empty to prevent keyboard conflicts
            if viewModel.newName.isEmpty {
                viewModel.newName = user.name
            }
        }
    }

    private func formatDate(_ timestamp: TimeInterval) -> String {
        let date = Date(timeIntervalSince1970: timestamp)
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

#Preview {
    ProfileView()
}
