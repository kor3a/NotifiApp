//
//  SubscriptionPaywallView.swift
//  Geolocation_v1.0.0
//
//  Created by Claude on 2/22/26.
//

import SwiftUI

struct SubscriptionPaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                // Icon
                Image(systemName: "lock.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(.linearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))

                // Title
                Text("AI Recipe is a Premium Feature")
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                // Description
                Text("Subscribe to unlock the AI Recipe Assistant and get personalized recipes, ingredient lists, and more.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                // Feature list
                VStack(alignment: .leading, spacing: 12) {
                    featureRow(icon: "fork.knife.circle.fill", text: "Ask for any recipe")
                    featureRow(icon: "cart.badge.plus", text: "Add ingredients directly to your stores")
                    featureRow(icon: "sparkles", text: "Auto-categorize ingredients")
                }
                .padding(.horizontal, 32)
                .padding(.top, 8)

                Spacer()

                // Info text
                Text("Contact the app administrator to activate your subscription.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 16)
            }
            .background(Color.backgroundGradient(for: colorScheme).ignoresSafeArea())
            .navigationTitle("AI Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.blue)
                .frame(width: 28)
            Text(text)
                .font(.subheadline)
        }
    }
}

#Preview {
    SubscriptionPaywallView()
}
