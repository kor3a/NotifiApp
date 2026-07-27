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
            VStack(spacing: 24) {
                Spacer()
                    .frame(height: 40)

                VStack(spacing: 8) {
                    Text("Almost there")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )

                    Text("Choose how you'll appear in Allim.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.bottom, 8)

                if !viewModel.errorMessage.isEmpty {
                    Text(viewModel.errorMessage)
                        .foregroundStyle(.red)
                        .font(.caption)
                        .padding(.horizontal)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        TextField("User ID", text: $viewModel.username)
                            .textFieldStyle(.plain)
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)
                            .focused($focusedField, equals: .username)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .name }
                            .padding()
                            .background(fieldBackground)
                            .overlay(alignment: .trailing) {
                                if viewModel.isPreparingSuggestions {
                                    ProgressView()
                                        .padding(.trailing, 16)
                                }
                            }

                        Text("3-20 letters and numbers. This is how friends find you.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.leading, 4)
                    }

                    TextField("Name", text: $viewModel.name)
                        .textFieldStyle(.plain)
                        .textInputAutocapitalization(.words)
                        .disableAutocorrection(true)
                        .focused($focusedField, equals: .name)
                        .submitLabel(.done)
                        .onSubmit { viewModel.createProfile() }
                        .padding()
                        .background(fieldBackground)

                    // Provider-supplied and fixed — shown so the user knows which
                    // account they're setting up, but not editable.
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(viewModel.email)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)

                            Spacer()

                            Image(systemName: "lock.fill")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(fieldBackground)

                        Text("From your \(viewModel.providerLabel) account. This can't be changed.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.leading, 4)
                    }
                }
                .padding(.horizontal, 20)

                Button(action: {
                    focusedField = nil
                    viewModel.createProfile()
                }) {
                    ZStack {
                        Text("Continue")
                            .font(.headline)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .opacity(viewModel.isLoading ? 0 : 1)

                        if viewModel.isLoading {
                            ProgressView()
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(
                                        LinearGradient(
                                            colors: [.blue, .purple],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        ),
                                        lineWidth: 1.5
                                    )
                            )
                    )
                }
                .disabled(viewModel.isLoading)
                .padding(.horizontal, 20)
                .padding(.top, 8)

                Button("Sign Out") {
                    viewModel.signOut()
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
                .disabled(viewModel.isLoading)

                Spacer()
            }//:VSTACK
        }//:SCROLLVIEW
        .scrollDismissesKeyboard(.interactively)
        .background(
            Color.backgroundGradient(for: colorScheme)
                .ignoresSafeArea()
        )
        .onAppear {
            viewModel.loadSuggestions()
        }
    }

    private var fieldBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.cardBorder(for: colorScheme), lineWidth: 1.5)
            )
    }
}

#Preview {
    ProfileSetupView()
}
