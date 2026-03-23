//
//  SubscriptionPaywallView.swift
//  Geolocation_v1.0.0
//

import SwiftUI
import StoreKit

struct SubscriptionPaywallView: View {
    @Environment(\.dismiss) private var dismiss

    private let appleEULAURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

    var body: some View {
        NavigationStack {
            SubscriptionStoreView(productIDs: [SubscriptionManager.monthlyProductID]) {
                VStack(spacing: 20) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(.linearGradient(
                            colors: [.yellow, .orange],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))

                    VStack(spacing: 6) {
                        Text("Allim Premium")
                            .font(.title)
                            .fontWeight(.bold)
                        Text("Unlock the full experience")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        featureRow(icon: "fork.knife.circle.fill", color: .blue,
                                   title: "Smart Recipe",
                                   description: "Ask for any recipe and add ingredients directly to your stores")
                        featureRow(icon: "sparkles", color: .purple,
                                   title: "Smart Category",
                                   description: "AI auto-categorizes every item you add to your shopping list")
                        featureRow(icon: "hand.thumbsup.fill", color: .green,
                                   title: "Ad-Free Experience",
                                   description: "Enjoy the app without any banner advertisements")
                    }
                    .padding(.horizontal, 28)
                    .padding(.vertical, 20)
                    .background(RoundedRectangle(cornerRadius: 16).fill(.ultraThinMaterial))
                    .padding(.horizontal, 20)
                }
                .padding(.top, 24)
            }
            .storeButton(.visible, for: .restorePurchases)
            .subscriptionStorePolicyDestination(url: appleEULAURL, for: .termsOfService)
            .subscriptionStorePolicyDestination(for: .privacyPolicy) { PrivacyPolicyView() }
            .onInAppPurchaseCompletion { _, result in
                if case .success(let purchaseResult) = result,
                   case .success = purchaseResult {
                    await SubscriptionManager.shared.refreshSubscriptionStatus()
                    dismiss()
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                }
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
