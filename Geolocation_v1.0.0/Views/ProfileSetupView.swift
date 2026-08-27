//
//  ProfileSetupView.swift
//  Geolocation_v1.0.0
//
//  One-time setup shown after a first-time Apple/Google sign-in, before the user
//  reaches the main app. They choose a username and name; the email comes from
//  the provider and can't be changed.
//

import SwiftUI

struct ProfileSetupView: View {

    @StateObject private var viewModel = ProfileSetupViewModel()
    @Environment(\.colorScheme) var colorScheme
    @FocusState private var focusedField: Field?

    private enum Field {
        case username, name
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                Spacer()
                    .frame(height: 32)

                VStack(spacing: 10) {
                    Text("Almost there")
                        .font(OrganicPalette.display(34))
                        .foregroundColor(OrganicPalette.ink(colorScheme))

                    Text("Choose how you'll appear in Allim.")
                        .font(OrganicPalette.body(16))
                        .foregroundColor(OrganicPalette.inkSoft(colorScheme))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 4)

                if !viewModel.errorMessage.isEmpty {
                    Text(viewModel.errorMessage)
                        .font(OrganicPalette.body(13))
                        .foregroundColor(OrganicPalette.rust(colorScheme))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        TextField(
                            "",
                            text: $viewModel.username,
                            prompt: OrganicPalette.prompt("User ID", colorScheme)
                        )
                        .font(OrganicPalette.body(17))
                        .foregroundColor(OrganicPalette.ink(colorScheme))
                        .textContentType(.username)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .focused($focusedField, equals: .username)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .name }
                        .organicField(colorScheme)

                        fieldNote("3-20 letters and numbers. This is how friends find you.")
                    }

                    TextField(
                        "",
                        text: $viewModel.name,
                        prompt: OrganicPalette.prompt("Name", colorScheme)
                    )
                    .font(OrganicPalette.body(17))
                    .foregroundColor(OrganicPalette.ink(colorScheme))
                    .textContentType(.name)
                    .textInputAutocapitalization(.words)
                    .disableAutocorrection(true)
                    .focused($focusedField, equals: .name)
                    .submitLabel(.done)
                    .onSubmit { viewModel.createProfile() }
                    .organicField(colorScheme)

                    // Provider-supplied and fixed — shown so the user knows which
                    // account they're setting up, but not editable. It keeps the
                    // capsule so the three rows line up, and states in soft ink
                    // rather than full ink that it is a fact, not a field.
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 10) {
                            Text(viewModel.email)
                                .font(OrganicPalette.body(17))
                                .foregroundColor(OrganicPalette.inkSoft(colorScheme))
                                .lineLimit(1)
                                .truncationMode(.middle)

                            Spacer(minLength: 0)

                            Image(systemName: "lock.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(OrganicPalette.inkSoft(colorScheme).opacity(0.7))
                        }
                        .organicField(colorScheme)

                        fieldNote("From your \(viewModel.providerLabel) account. This can't be changed.")
                    }
                }
                .padding(.horizontal, 20)

                OrganicPillButton(
                    title: "Continue",
                    isLoading: viewModel.isLoading,
                    fillsWidth: true
                ) {
                    focusedField = nil
                    viewModel.createProfile()
                }
                .disabled(viewModel.isLoading)
                .padding(.horizontal, 20)
                .padding(.top, 4)

                // The way back out of a half-finished account. Quiet ink, well
                // clear of Continue — it is the escape hatch, not the choice
                // this screen is asking anyone to make.
                Button("Sign Out") {
                    viewModel.signOut()
                }
                .font(OrganicPalette.body(14))
                .foregroundColor(OrganicPalette.inkSoft(colorScheme))
                .buttonStyle(.plain)
                .disabled(viewModel.isLoading)
                .padding(.top, 6)

                Spacer()
            }//:VSTACK
        }//:SCROLLVIEW
        .scrollDismissesKeyboard(.interactively)
        .background(
            OrganicPalette.canvas(colorScheme)
                .ignoresSafeArea()
        )
        .onAppear {
            viewModel.loadNameSuggestion()
        }
    }

    /// The line of explanation under a field, inset to sit under the capsule's
    /// own text rather than against its edge.
    private func fieldNote(_ text: String) -> some View {
        Text(text)
            .font(OrganicPalette.body(13))
            .foregroundColor(OrganicPalette.inkSoft(colorScheme).opacity(0.85))
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 18)
    }
}

#Preview {
    ProfileSetupView()
}
