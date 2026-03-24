//
//  SubscriptionManagementView.swift
//  Geolocation_v1.0.0
//

import SwiftUI
import StoreKit

struct SubscriptionManagementView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var showManageError = false
    @State private var manageErrorMessage = ""
    @State private var showPrivacy = false

    private let appleEULAURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    Spacer(minLength: 16)

                    // Hero icon
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.yellow.opacity(0.2), .orange.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 100, height: 100)

                        Image(systemName: "crown.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.linearGradient(
                                colors: [.yellow, .orange],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                    }

                    // Title
                    VStack(spacing: 6) {
                        Text("Allim Premium")
                            .font(.title)
                            .fontWeight(.bold)
                        Text("Active Subscription")
                            .font(.subheadline)
                            .foregroundColor(.green)
                            .fontWeight(.semibold)
                    }

                    // Active features card
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Your Premium Features")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                            .padding(.bottom, 4)

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
                    .padding(.horizontal, 20)
                    .padding(.vertical, 20)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.ultraThinMaterial)
                    )
                    .padding(.horizontal, 20)

                    // Pricing info
                    if let active = subscriptionManager.activeProduct {
                        let isAnnual = active.id == SubscriptionManager.annualProductID
                        VStack(spacing: 4) {
                            Text("\(active.displayPrice) / \(isAnnual ? "year" : "month")")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Text("Renews automatically unless cancelled")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    // Manage subscription button
                    Button {
                        Task {
                            await openManageSubscriptions()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "gear")
                            Text("Manage Subscription")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
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
                    .padding(.horizontal, 20)

                    // Unsubscribe / Cancel info
                    VStack(spacing: 8) {
                        Button {
                            Task {
                                await openManageSubscriptions()
                            }
                        } label: {
                            Text("Cancel Subscription")
                                .font(.subheadline)
                                .foregroundColor(.red)
                        }

                        Text("To cancel, tap above to open App Store subscription settings and turn off auto-renewal for Allim Premium.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }

                    // Legal
                    VStack(spacing: 10) {
                        let isAnnual = subscriptionManager.activeProduct?.id == SubscriptionManager.annualProductID
                        Text("Allim Premium · \(isAnnual ? "Annual" : "Monthly") Subscription")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                        Text("Subscription auto-renews \(isAnnual ? "annually" : "monthly") unless cancelled at least 24 hours before the end of the current period. Manage or cancel anytime in App Store Settings.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        HStack(spacing: 16) {
                            Link("Terms of Use", destination: appleEULAURL)
                                .font(.caption2)
                            Text("·")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Button("Privacy Policy") { showPrivacy = true }
                                .font(.caption2)
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
                    .sheet(isPresented: $showPrivacy) { PrivacyPolicyView() }
                }
            }
            .background(Color.backgroundGradient(for: colorScheme).ignoresSafeArea())
            .navigationTitle("Subscription")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
            .alert("Unable to Open Settings", isPresented: $showManageError) {
                Button("OK") { }
            } message: {
                Text(manageErrorMessage)
            }
        }
    }

    private func openManageSubscriptions() async {
        if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
            do {
                try await AppStore.showManageSubscriptions(in: scene)
            } catch {
                manageErrorMessage = "Could not open subscription settings. Please go to Settings > Apple ID > Subscriptions to manage your subscription."
                showManageError = true
            }
        } else {
            if let url = URL(string: "itms-apps://apps.apple.com/account/subscriptions") {
                await UIApplication.shared.open(url)
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
    SubscriptionManagementView()
}
