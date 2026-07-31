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
    @State private var selectedPlan: String = SubscriptionManager.annualProductID
    @State private var showPrivacy = false

    private let appleEULAURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

    // Savings % compared to paying monthly for a full year
    private var savingsPercent: Int? {
        guard let monthly = subscriptionManager.product,
              let annual = subscriptionManager.annualProduct else { return nil }
        let monthlyDouble = NSDecimalNumber(decimal: monthly.price).doubleValue
        let annualDouble  = NSDecimalNumber(decimal: annual.price).doubleValue
        guard monthlyDouble > 0 else { return nil }
        let monthlyAnnualized = monthlyDouble * 12
        let pct = (monthlyAnnualized - annualDouble) / monthlyAnnualized * 100
        return pct > 0 ? Int(pct.rounded()) : nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Spacer(minLength: 8)

                    // Hero
                    VStack(spacing: 10) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(.linearGradient(
                                colors: [.yellow, .orange],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                        Text("Allim Premium")
                            .font(.title)
                            .fontWeight(.bold)
                        Text("Unlock the full experience")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    // Feature rows
                    VStack(alignment: .leading, spacing: 16) {
                        featureRow(icon: "infinity.circle.fill", color: .orange,
                                   title: "Unlimited Stores & Items",
                                   description: "Free accounts are limited to \(SubscriptionManager.freeStoreLimit) stores and \(SubscriptionManager.freeReminderLimitPerStore) items per store — go unlimited with Premium")
                        featureRow(icon: "fork.knife.circle.fill", color: .blue,
                                   title: "Smart Recipe",
                                   description: "Ask for any recipe and add ingredients directly to your stores")
                        featureRow(icon: "sparkles", color: .purple,
                                   title: "Smart Category",
                                   description: "AI auto-categorizes every item you add to your shopping list")
                        featureRow(icon: "chart.bar.xaxis", color: .indigo,
                                   title: "Store Analytics",
                                   description: "Shopping trends, category breakdowns, and your most-gotten items for every store")
                        featureRow(icon: "paintpalette.fill", color: .pink,
                                   title: "Custom Backgrounds",
                                   description: "Pick your own background color for your screens")
                        featureRow(icon: "hand.thumbsup.fill", color: .green,
                                   title: "Ad-Free Experience",
                                   description: "Enjoy the app without any banner advertisements")
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 20)
                    .background(RoundedRectangle(cornerRadius: 16).fill(.ultraThinMaterial))
                    .padding(.horizontal, 20)

                    // Plan comparison
                    HStack(spacing: 12) {
                        planCard(
                            planID: SubscriptionManager.monthlyProductID,
                            title: "Monthly",
                            price: subscriptionManager.product?.displayPrice ?? "—",
                            period: "per month",
                            badge: nil,
                            trialText: "7-day free trial"
                        )
                        planCard(
                            planID: SubscriptionManager.annualProductID,
                            title: "Annual",
                            price: subscriptionManager.annualProduct?.displayPrice ?? "$10.00",
                            period: "per year",
                            badge: savingsPercent.map { "Save \($0)%" } ?? "Best Value",
                            trialText: "7-day free trial"
                        )
                    }
                    .padding(.horizontal, 20)

                    // Subscribe button
                    Button {
                        Task {
                            let productToBuy = selectedPlan == SubscriptionManager.annualProductID
                                ? subscriptionManager.annualProduct
                                : subscriptionManager.product
                            guard let productToBuy else { return }
                            await subscriptionManager.purchase(productToBuy)
                            if subscriptionManager.isSubscribed { dismiss() }
                        }
                    } label: {
                        Group {
                            if subscriptionManager.isPurchasing {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                VStack(spacing: 2) {
                                    Text("Start Free Trial")
                                        .font(.headline)
                                    Text("7 days free, then auto-renews")
                                        .font(.caption2)
                                        .opacity(0.85)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [.yellow, .orange],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(subscriptionManager.isPurchasing)
                    .padding(.horizontal, 20)

                    if let error = subscriptionManager.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }

                    // Restore purchases
                    Button {
                        Task { await subscriptionManager.restorePurchases() }
                    } label: {
                        Text("Restore Purchases")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    // Legal
                    VStack(spacing: 8) {
                        Text("Subscription renews automatically unless cancelled at least 24 hours before the end of the current period. Manage or cancel anytime in App Store Settings.")
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
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func planCard(planID: String, title: String, price: String, period: String, badge: String?, trialText: String? = nil) -> some View {
        let isSelected = selectedPlan == planID
        Button { selectedPlan = planID } label: {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 6) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(isSelected ? .white : .primary)
                    Text(price)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(isSelected ? .white : .primary)
                    Text(period)
                        .font(.caption)
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                    if let trialText {
                        Text(trialText)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(isSelected ? .white : .green)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(isSelected ? Color.white.opacity(0.25) : Color.green.opacity(0.15))
                            )
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .padding(.top, badge != nil ? 10 : 0)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(isSelected
                            ? AnyShapeStyle(LinearGradient(
                                colors: [.yellow, .orange],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing))
                            : AnyShapeStyle(.ultraThinMaterial))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(
                            isSelected ? Color.clear : Color.secondary.opacity(0.2),
                            lineWidth: 1
                        )
                )

                if let badge {
                    Text(badge)
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.green))
                        .offset(x: -10, y: -10)
                }
            }
        }
        .buttonStyle(.plain)
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
