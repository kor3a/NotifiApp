//
//  ProfileView.swift
//  Geolocation_v1.0.0
//
//  Created by Subong Jeon on 8/5/24.
//

import SwiftUI
import FirebaseAuth

struct ProfileView: View {

    @StateObject private var viewModel = ProfileViewModel()
    @State private var showImagePicker = false
    @State private var selectedImage: UIImage?

    var body: some View {
        if viewModel.isLoading {
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
                Text(!viewModel.errorMessage.isEmpty ? viewModel.errorMessage : "No user data available")
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding()
                Button("Retry") {
                    viewModel.fetchUser()
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
                Button {
                    viewModel.saveProfileChanges()
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.blue)
                            .frame(height: 50)

                        Text("Save Changes")
                            .font(.headline)
                            .foregroundStyle(.white)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 20)

                // Sign Out Button
                Button {
                    viewModel.signOut()
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(.red.opacity(0.1))
                            .frame(height: 50)

                        Text("Sign Out")
                            .font(.headline)
                            .foregroundStyle(.red)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 10)
                .padding(.bottom, 30)
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
