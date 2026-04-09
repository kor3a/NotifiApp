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
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared
    @State private var showImagePicker = false
    @State private var selectedImage: UIImage?
    @State private var showDeleteAccountAlert = false
    @State private var reauthPassword = ""
    @State private var showSubscriptionSheet = false

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
        List {
            // MARK: - Profile Picture & Info
            Section {
                HStack(alignment: .center, spacing: 16) {
                    // Profile Picture
                    Button {
                        showImagePicker = true
                    } label: {
                        if let selectedImage = selectedImage {
                            Image(uiImage: selectedImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 70, height: 70)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.blue, lineWidth: 2))
                        } else if let profilePictureURL = user.profilePictureURL,
                                  let url = URL(string: profilePictureURL) {
                            AsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 70, height: 70)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(Color.blue, lineWidth: 2))
                            } placeholder: {
                                Image(systemName: "person.circle.fill")
                                    .resizable()
                                    .frame(width: 70, height: 70)
                                    .foregroundStyle(.gray)
                            }
                        } else {
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .frame(width: 70, height: 70)
                                .foregroundStyle(.gray)
                        }
                    }
                    .sheet(isPresented: $showImagePicker) {
                        ImagePicker(selectedImage: $selectedImage, onImageSelected: { image in
                            viewModel.uploadProfilePicture(image: image)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                selectedImage = nil
                            }
                        })
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(user.name)
                            .font(.title3)
                            .bold()

                        Text("@\(user.userId)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Text(user.email)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
                .padding(.vertical, 8)
            }

            // MARK: - Ad Banner (non-subscribers only)
            if !subscriptionManager.isSubscribed {
                Section {
                    BannerAdView(adUnitID: kBannerAdUnitID)
                        .frame(height: 50)
                        .listRowInsets(EdgeInsets())
                }
            }

            // MARK: - Navigation Rows
            Section {
                NavigationLink {
                    AccountSecurityView(viewModel: viewModel)
                } label: {
                    Label("Account Security", systemImage: "lock.fill")
                }

                NavigationLink {
                    AboutView()
                } label: {
                    Label("About Allim Smart Shopping List", systemImage: "info.circle.fill")
                }

                NavigationLink {
                    ReportFeedbackView()
                } label: {
                    Label("Report Errors and Feedback", systemImage: "exclamationmark.bubble.fill")
                }
            }

            // MARK: - Account Actions
            Section {
                Button("Sign Out") {
                    viewModel.signOut()
                }
                .foregroundStyle(.red)

                Button("Delete Account") {
                    showDeleteAccountAlert = true
                }
                .foregroundStyle(.red)
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
            }

            #if DEBUG
            Section {
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
                .foregroundStyle(.orange)

                NavigationLink("Subscription Debug") {
                    SubscriptionDebugView()
                }
                .foregroundStyle(.orange)
            }
            #endif
        }
        .listStyle(.insetGrouped)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showSubscriptionSheet = true
                } label: {
                    Image(systemName: subscriptionManager.isSubscribed ? "crown.fill" : "crown")
                        .foregroundStyle(subscriptionManager.isSubscribed
                            ? AnyShapeStyle(.linearGradient(colors: [.yellow, .orange], startPoint: .topLeading, endPoint: .bottomTrailing))
                            : AnyShapeStyle(.secondary)
                        )
                        .imageScale(.large)
                }
            }
        }
        .sheet(isPresented: $showSubscriptionSheet) {
            if subscriptionManager.isSubscribed {
                SubscriptionManagementView()
            } else {
                SubscriptionPaywallView()
            }
        }
        .onAppear {
            if viewModel.newName.isEmpty {
                viewModel.newName = user.name
            }
        }
    }
}

#Preview {
    ProfileView()
}
