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
            VStack(spacing: 22) {
                Spacer()
                    .frame(height: 28)

                VStack(spacing: 10) {
                    Text("Forgot Password")
                        .font(OrganicPalette.display(32))
                        .foregroundColor(OrganicPalette.ink(colorScheme))
                        .multilineTextAlignment(.center)

                    Text("Enter your email address and we'll send you instructions to reset your password.")
                        .font(OrganicPalette.body(16))
                        .foregroundColor(OrganicPalette.inkSoft(colorScheme))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 4)

                if !viewModel.errorMessage.isEmpty || !viewModel.successMessage.isEmpty {
                    statusCard
                        .padding(.horizontal, 20)
                }

                TextField(
                    "",
                    text: $viewModel.email,
                    prompt: OrganicPalette.prompt("Email", colorScheme)
                )
                .font(OrganicPalette.body(17))
                .foregroundColor(OrganicPalette.ink(colorScheme))
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.send)
                .onSubmit { viewModel.sendPasswordReset() }
                .organicField(colorScheme)
                .padding(.horizontal, 20)

                OrganicPillButton(
                    title: "Send Reset Email",
                    isLoading: viewModel.isLoading,
                    fillsWidth: true
                ) {
                    viewModel.sendPasswordReset()
                }
                .disabled(viewModel.isLoading)
                .padding(.horizontal, 20)
                .padding(.top, 4)

                Button(action: {
                    dismiss()
                }) {
                    Text("Back to Login")
                        .font(OrganicPalette.body(14))
                        .foregroundColor(OrganicPalette.inkSoft(colorScheme))
                        .underline()
                }
                .buttonStyle(.plain)
                .padding(.top, 6)

                Spacer()

            }//:VSTACK
        }//:SCROLLVIEW
        .scrollDismissesKeyboard(.interactively)
        .background(
            OrganicPalette.canvas(colorScheme)
                .ignoresSafeArea()
        )
        // Pushed onto LoginView's stack, so the back chevron is this screen's
        // to tint.
        .toolbarBackground(OrganicPalette.canvas(colorScheme), for: .navigationBar)
        .tint(OrganicPalette.terracotta(colorScheme))
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
                .font(OrganicPalette.body(15))
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

#Preview {
    ForgotPasswordView()
}
