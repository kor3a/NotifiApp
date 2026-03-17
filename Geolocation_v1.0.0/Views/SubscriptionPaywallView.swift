//
//  SubscriptionPaywallView.swift
//  Geolocation_v1.0.0
//

import SwiftUI
import StoreKit

struct SubscriptionPaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var showError = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    Spacer(minLength: 16)

                    // Hero icon
                    Image(systemName: "crown.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(.linearGradient(
                            colors: [.yellow, .orange],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))

                    // Title
                    VStack(spacing: 6) {
                        Text("Allim Premium")
                            .font(.title)
                            .fontWeight(.bold)
                        Text("Unlock the full experience")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    // Feature list
                    VStack(alignment: .leading, spacing: 16) {
                        featureRow(
                            icon: "fork.knife.circle.fill",
                            color: .blue,
                            title: "Smart Recipe",
                            description: "Ask for any recipe and add ingredients directly to your stores"
                        )
                        featureRow(
                            icon: "sparkles",
                            color: .purple,
                            title: "Smart Category",
                            description: "AI auto-categorizes every item you add to your shopping list"
                        )
                        featureRow(
                            icon: "hand.thumbsup.fill",
                            color: .green,
                            title: "Ad-Free Experience",
                            description: "Enjoy the app without any banner advertisements"
                        )
                    }
                    .padding(.horizontal, 28)
                    .padding(.vertical, 20)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.ultraThinMaterial)
                    )
                    .padding(.horizontal, 20)

                    // Pricing card
                    VStack(spacing: 8) {
                        if let product = subscriptionManager.product {
                            Text(product.displayPrice)
                                .font(.system(size: 36, weight: .bold))
                            Text("per month")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        } else {
                            Text("$0.99")
                                .font(.system(size: 36, weight: .bold))
                            Text("per month")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        Text("7-day free trial, then billed monthly")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 2)
                    }

                    // Subscribe button
                    Button {
                        Task {
                            await subscriptionManager.purchase()
                            if subscriptionManager.isSubscribed {
                                dismiss()
                            }
                        }
                    } label: {
                        ZStack {
                            if subscriptionManager.isPurchasing {
                                ProgressView()
                                    .tint(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                            } else {
                                Text("Start Free Trial")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                            }
                        }
                        .background(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(subscriptionManager.isPurchasing)
                    .padding(.horizontal, 20)

                    // Restore purchases
                    Button {
                        Task {
                            await subscriptionManager.restorePurchases()
                            if subscriptionManager.isSubscribed {
                                dismiss()
                            }
                        }
                    } label: {
                        Text("Restore Purchases")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                    }
                    .disabled(subscriptionManager.isPurchasing)

                    // Legal
                    Text("Subscription auto-renews at $0.99/month unless cancelled at least 24 hours before the end of the current period. Free trial converts to a paid subscription if not cancelled. Manage or cancel in App Store Settings.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 16)
                }
            }
            .background(Color.backgroundGradient(for: colorScheme).ignoresSafeArea())
            .navigationTitle("Go Premium")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
            .alert("Purchase Error", isPresented: Binding(
                get: { subscriptionManager.errorMessage != nil },
                set: { if !$0 { subscriptionManager.errorMessage = nil } }
            )) {
                Button("OK") { subscriptionManager.errorMessage = nil }
            } message: {
                Text(subscriptionManager.errorMessage ?? "")
            }
        }
    }

    private func featureRow(icon: String, color: Color, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

#Preview {
    SubscriptionPaywallView()
}
