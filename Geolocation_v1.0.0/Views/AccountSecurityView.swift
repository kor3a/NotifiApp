//
//  AccountSecurityView.swift
//  Geolocation_v1.0.0
//

import SwiftUI

struct AccountSecurityView: View {

    @ObservedObject var viewModel: ProfileViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            OrganicPalette.canvas(colorScheme)
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if !viewModel.successMessage.isEmpty || !viewModel.errorMessage.isEmpty {
                        statusCard
                    }

                    displayNameSection

                    // Accounts created with Apple or Google have no password to change.
                    if viewModel.canChangePassword {
                        passwordSection
                    }

                    OrganicPillButton(title: "Save Changes", fillsWidth: true) {
                        viewModel.saveProfileChanges()
                    }
                    .disabled(viewModel.isLoading)
                    .padding(.top, 4)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
            .scrollDismissesKeyboard(.immediately)

            if viewModel.isLoading {
                Color.black.opacity(0.15)
                    .ignoresSafeArea()

                ProgressView()
                    .scaleEffect(1.4)
                    .tint(OrganicPalette.terracotta(colorScheme))
                    .padding(28)
                    .background(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(OrganicPalette.surface(colorScheme))
                    )
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(OrganicPalette.canvas(colorScheme), for: .navigationBar)
        .tint(OrganicPalette.terracotta(colorScheme))
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Account Security")
                    .font(OrganicPalette.title(17))
                    .foregroundColor(OrganicPalette.ink(colorScheme))
            }
        }
    }

    // MARK: - Sections

    private var displayNameSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            OrganicSectionLabel(title: "Display name")

            Text("What friends see when you share a store or a list with them.")
                .font(.system(size: 14))
                .foregroundColor(OrganicPalette.inkSoft(colorScheme))

            TextField(
                "",
                text: $viewModel.newName,
                prompt: Text("Enter your name")
                    .foregroundColor(OrganicPalette.inkSoft(colorScheme).opacity(0.8))
            )
            .font(.system(size: 17))
            .foregroundColor(OrganicPalette.ink(colorScheme))
            .textInputAutocapitalization(.words)
            .autocorrectionDisabled()
            .organicField(colorScheme)
        }
    }

    private var passwordSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            OrganicSectionLabel(title: "Change password")

            Text("Leave both fields blank to keep your current password.")
                .font(.system(size: 14))
                .foregroundColor(OrganicPalette.inkSoft(colorScheme))

            secureField("New password", text: $viewModel.newPassword)
            secureField("Confirm new password", text: $viewModel.confirmPassword)
        }
    }

    private func secureField(_ prompt: String, text: Binding<String>) -> some View {
        SecureField(
            "",
            text: text,
            prompt: Text(prompt)
                .foregroundColor(OrganicPalette.inkSoft(colorScheme).opacity(0.8))
        )
        .font(.system(size: 17))
        .foregroundColor(OrganicPalette.ink(colorScheme))
        .organicField(colorScheme)
    }

    /// Success in sage, failure in rust — the same two answers the rest of the
    /// app gives, rather than the system's green and red.
    private var statusCard: some View {
        let isSuccess = !viewModel.successMessage.isEmpty
        let tint = isSuccess
            ? OrganicPalette.sageInk(colorScheme)
            : OrganicPalette.rust(colorScheme)

        return HStack(spacing: 12) {
            Image(systemName: isSuccess ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .font(.system(size: 18))
                .foregroundColor(tint)

            Text(isSuccess ? viewModel.successMessage : viewModel.errorMessage)
                .font(.system(size: 15))
                .foregroundColor(OrganicPalette.ink(colorScheme))
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            OrganicCardBackground(
                colorScheme: colorScheme,
                fill: isSuccess
                    ? OrganicPalette.sage(colorScheme)
                    : OrganicPalette.blush(colorScheme)
            )
        )
    }
}
