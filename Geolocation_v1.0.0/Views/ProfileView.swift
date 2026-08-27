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
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var viewModel = ProfileViewModel()
    @ObservedObject private var sessionManager = UserSessionManager.shared
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared
    @State private var showImagePicker = false
    @State private var selectedImage: UIImage?
    @State private var showDeleteAccountAlert = false
    @State private var reauthPassword = ""
    @State private var showSubscriptionSheet = false

    var body: some View {
        ZStack {
            OrganicPalette.canvas(colorScheme)
                .ignoresSafeArea()

            if sessionManager.isLoading || viewModel.isLoading {
                loadingState
            } else if let user = viewModel.user {
                profileEditView(user: user)
            } else {
                unavailableState
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(OrganicPalette.canvas(colorScheme), for: .navigationBar)
        .tint(OrganicPalette.terracotta(colorScheme))
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Profile")
                    .font(.system(size: 17, weight: .bold, design: .serif))
                    .foregroundColor(OrganicPalette.ink(colorScheme))
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showSubscriptionSheet = true
                } label: {
                    Image(systemName: subscriptionManager.isSubscribed ? "crown.fill" : "crown")
                        .foregroundColor(
                            subscriptionManager.isSubscribed
                                ? OrganicPalette.terracotta(colorScheme)
                                : OrganicPalette.inkSoft(colorScheme)
                        )
                        .imageScale(.large)
                }
                .accessibilityLabel(subscriptionManager.isSubscribed ? "Manage subscription" : "Allim Premium")
            }
        }
        .sheet(isPresented: $showSubscriptionSheet) {
            if subscriptionManager.isSubscribed {
                SubscriptionManagementView()
            } else {
                SubscriptionPaywallView()
            }
        }
    }

    // MARK: - States

    private var loadingState: some View {
        VStack(spacing: 14) {
            ProgressView()
                .scaleEffect(1.4)
                .tint(OrganicPalette.terracotta(colorScheme))

            Text("Loading profile...")
                .font(.system(size: 16))
                .foregroundColor(OrganicPalette.inkSoft(colorScheme))
        }
    }

    private var unavailableState: some View {
        VStack(spacing: 14) {
            OrganicEmptyState(
                systemImage: "exclamationmark.triangle",
                title: "Profile unavailable",
                message: !sessionManager.errorMessage.isEmpty
                    ? sessionManager.errorMessage
                    : "We couldn't load your account just now.",
                actionTitle: "Try again",
                action: { sessionManager.fetchUser() }
            )

            Button("Sign Out") {
                viewModel.signOut()
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(OrganicPalette.rust(colorScheme))
        }
    }

    // MARK: - Profile

    @ViewBuilder
    func profileEditView(user: User) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                identityCard(user: user)

                if !subscriptionManager.isSubscribed {
                    BannerAdView(adUnitID: kBannerAdUnitID)
                        .frame(height: 50)
                }

                settingsSection

                accountActionsSection

                #if DEBUG
                debugSection
                #endif
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(selectedImage: $selectedImage, onImageSelected: { image in
                viewModel.uploadProfilePicture(image: image)
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    selectedImage = nil
                }
            })
        }
        .onAppear {
            if viewModel.newName.isEmpty {
                viewModel.newName = user.name
            }
        }
    }

    /// Who you are, and the one thing on this screen you edit by tapping rather
    /// than by opening another screen.
    private func identityCard(user: User) -> some View {
        VStack(spacing: 16) {
            Button {
                showImagePicker = true
            } label: {
                avatar(for: user)
                    .overlay(alignment: .bottomTrailing) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(OrganicPalette.terracotta(colorScheme)))
                            .overlay(
                                Circle().strokeBorder(OrganicPalette.surface(colorScheme), lineWidth: 2.5)
                            )
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Change profile picture")

            VStack(spacing: 4) {
                HStack(spacing: 8) {
                    Text(user.name)
                        .font(OrganicPalette.display(26))
                        .foregroundColor(OrganicPalette.ink(colorScheme))
                        .lineLimit(1)

                    if subscriptionManager.isSubscribed {
                        Text("PREMIUM")
                            .font(.system(size: 10, weight: .bold))
                            .kerning(0.6)
                            .foregroundColor(OrganicPalette.sageInk(colorScheme))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(OrganicPalette.sage(colorScheme)))
                    }
                }

                Text("@\(user.userId)")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(OrganicPalette.inkSoft(colorScheme))
                    .lineLimit(1)

                Text(user.email)
                    .font(.system(size: 14))
                    .foregroundColor(OrganicPalette.inkSoft(colorScheme).opacity(0.85))
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
        .background(OrganicCardBackground(colorScheme: colorScheme, cornerRadius: 28))
    }

    /// The picture being uploaded right now wins over the stored one, so the
    /// new photo appears the moment it's picked rather than after the upload
    /// round-trips.
    @ViewBuilder
    private func avatar(for user: User) -> some View {
        if let selectedImage {
            Image(uiImage: selectedImage)
                .resizable()
                .scaledToFill()
                .frame(width: 92, height: 92)
                .clipShape(Circle())
        } else {
            OrganicAvatar(
                name: user.name,
                profilePictureURL: user.profilePictureURL,
                size: 92
            )
        }
    }

    // MARK: - Sections

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            OrganicSectionLabel(title: "Account")

            NavigationLink {
                AccountSecurityView(viewModel: viewModel)
            } label: {
                OrganicNavRow(
                    systemImage: "lock.fill",
                    title: "Account Security",
                    subtitle: "Your display name and password"
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                AboutView()
            } label: {
                OrganicNavRow(
                    systemImage: "info.circle.fill",
                    title: "About Allim",
                    subtitle: "Version, privacy policy and what the app does"
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                ReportFeedbackView()
            } label: {
                OrganicNavRow(
                    systemImage: "exclamationmark.bubble.fill",
                    title: "Report Errors and Feedback",
                    subtitle: "Tell us what's broken or what you'd like next"
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var accountActionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            OrganicSectionLabel(title: "Account actions")

            Button {
                viewModel.signOut()
            } label: {
                OrganicNavRow(
                    systemImage: "rectangle.portrait.and.arrow.right",
                    title: "Sign Out",
                    tint: OrganicPalette.inkSoft(colorScheme),
                    accessory: nil
                )
            }
            .buttonStyle(.plain)

            Button {
                showDeleteAccountAlert = true
            } label: {
                OrganicNavRow(
                    systemImage: "trash.fill",
                    title: "Delete Account",
                    subtitle: "Permanently removes your account and everything in it",
                    tint: OrganicPalette.rust(colorScheme),
                    accessory: nil
                )
            }
            .buttonStyle(.plain)
            .alert("Delete Account", isPresented: $showDeleteAccountAlert) {
                Button("Delete", role: .destructive) {
                    viewModel.deleteAccount()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text(deleteAccountMessage)
            }
            // Only password accounts get here — Apple/Google accounts confirm
            // through their provider's sheet instead.
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
    }

    #if DEBUG
    private var debugSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            OrganicSectionLabel(title: "Debug")

            Button {
                TutorialManager.shared.resetTutorial()
                dismiss()
                TutorialManager.shared.pendingTabSwitch = 0
                if let userId = sessionManager.currentUser?.userId {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        TutorialManager.shared.startIfNeeded(userId: userId)
                    }
                }
            } label: {
                OrganicNavRow(
                    systemImage: "arrow.counterclockwise",
                    title: "Replay Tutorial",
                    accessory: nil
                )
            }
            .buttonStyle(.plain)

            // Replays the primer screens themselves. The iOS prompts behind
            // them are one-shot per install, so an already-answered
            // permission just advances when its button is tapped.
            Button {
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    PermissionOnboardingManager.shared.replayForDebug()
                }
            } label: {
                OrganicNavRow(
                    systemImage: "hand.raised",
                    title: "Replay Permission Screens",
                    accessory: nil
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                SubscriptionDebugView()
            } label: {
                OrganicNavRow(
                    systemImage: "ladybug",
                    title: "Subscription Debug"
                )
            }
            .buttonStyle(.plain)
        }
    }
    #endif

    /// Social accounts confirm deletion through their provider's sheet, so the
    /// warning tells them what to expect rather than implying a password prompt.
    private var deleteAccountMessage: String {
        let warning = "This will permanently delete your account and all associated data. This action cannot be undone."
        switch viewModel.reauthMethod {
        case .apple:
            return warning + "\n\nYou'll be asked to confirm with Apple first."
        case .google:
            return warning + "\n\nYou may be asked to confirm with Google first."
        case .password:
            return warning
        }
    }
}

#Preview {
    NavigationStack {
        ProfileView()
    }
}
