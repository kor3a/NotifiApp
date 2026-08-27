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
            ZStack {
                OrganicPalette.canvas(colorScheme)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        hero

                        featureCard

                        planCards

                        subscribeButton

                        if let error = subscriptionManager.errorMessage {
                            Text(error)
                                .font(.system(size: 13))
                                .foregroundColor(OrganicPalette.rust(colorScheme))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                        }

                        Button {
                            Task { await subscriptionManager.restorePurchases() }
                        } label: {
                            Text("Restore Purchases")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(OrganicPalette.inkSoft(colorScheme))
                        }
                        .buttonStyle(.plain)

                        legal
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 16)
                }
            }
            .toolbarBackground(OrganicPalette.canvas(colorScheme), for: .navigationBar)
            .tint(OrganicPalette.terracotta(colorScheme))
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundColor(OrganicPalette.terracotta(colorScheme))
                }
            }
            .sheet(isPresented: $showPrivacy) { PrivacyPolicyView(isModal: true) }
        }
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(spacing: 12) {
            Image(systemName: "crown.fill")
                .font(.system(size: 42))
                .foregroundColor(OrganicPalette.terracotta(colorScheme))
                .frame(width: 104, height: 104)
                .background(Circle().fill(OrganicPalette.blush(colorScheme)))

            Text("Allim Premium")
                .font(OrganicPalette.display(32))
                .foregroundColor(OrganicPalette.ink(colorScheme))

            Text("Unlock the full experience")
                .font(.system(size: 16))
                .foregroundColor(OrganicPalette.inkSoft(colorScheme))
        }
    }

    // MARK: - Features

    private var featureCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            featureRow(icon: "infinity",
                       title: "Unlimited Stores",
                       description: "Free accounts are limited to \(SubscriptionManager.freeStoreLimit) stores of your own — go unlimited with Premium")
            // Don't advertise what a release build can't deliver.
            if FeatureFlags.voiceCommands {
                featureRow(icon: "mic.fill",
                           title: "Voice Commands",
                           description: "Swipe any store and just say it — add items, check them off, or remove them, with a confirmation before anything changes")
            }
            featureRow(icon: "fork.knife",
                       title: "Smart Recipe",
                       description: "Ask for any recipe and add ingredients directly to your stores")
            featureRow(icon: "sparkles",
                       title: "Smart Category",
                       description: "AI auto-categorizes every item you add to your shopping list")
            featureRow(icon: "chart.bar.xaxis",
                       title: "Store Analytics",
                       description: "Shopping trends, category breakdowns, and your most-gotten items for every store")
            featureRow(icon: "photo.on.rectangle.angled",
                       title: "Photo Backgrounds",
                       description: "Use your own photos as the backdrop for any screen — colors are free for everyone")
            featureRow(icon: "hand.thumbsup.fill",
                       title: "Ad-Free Experience",
                       description: "Enjoy the app without any banner advertisements")
        }
        .padding(20)
        .background(OrganicCardBackground(colorScheme: colorScheme, cornerRadius: 28))
        .padding(.horizontal, 20)
    }

    /// One thing Premium gets you. Every glyph is terracotta on blush rather
    /// than a colour per feature — a seven-colour list reads as a toybox, and
    /// the point is the words beside them.
    private func featureRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(OrganicPalette.terracotta(colorScheme))
                .frame(width: 38, height: 38)
                .background(Circle().fill(OrganicPalette.blush(colorScheme)))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(OrganicPalette.ink(colorScheme))

                Text(description)
                    .font(.system(size: 13))
                    .foregroundColor(OrganicPalette.inkSoft(colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }

    // MARK: - Plans

    private var planCards: some View {
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
    }

    @ViewBuilder
    private func planCard(planID: String, title: String, price: String, period: String, badge: String?, trialText: String? = nil) -> some View {
        let isSelected = selectedPlan == planID

        Button { selectedPlan = planID } label: {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(isSelected ? .white : OrganicPalette.inkSoft(colorScheme))

                    Text(price)
                        .font(OrganicPalette.display(24))
                        .foregroundColor(isSelected ? .white : OrganicPalette.ink(colorScheme))

                    Text(period)
                        .font(.system(size: 13))
                        .foregroundColor(
                            isSelected ? .white.opacity(0.8) : OrganicPalette.inkSoft(colorScheme)
                        )

                    if let trialText {
                        Text(trialText)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(
                                isSelected ? .white : OrganicPalette.sageInk(colorScheme)
                            )
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                Capsule().fill(
                                    isSelected
                                        ? Color.white.opacity(0.25)
                                        : OrganicPalette.sage(colorScheme)
                                )
                            )
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .padding(.top, badge != nil ? 10 : 0)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(
                            isSelected
                                ? OrganicPalette.terracotta(colorScheme)
                                : OrganicPalette.surface(colorScheme)
                        )
                        .shadow(color: OrganicPalette.shadow(colorScheme), radius: 10, x: 0, y: 4)
                )

                if let badge {
                    Text(badge)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(OrganicPalette.sageInk(colorScheme))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(OrganicPalette.sage(colorScheme)))
                        .offset(x: -10, y: -10)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Subscribe

    /// Two lines of type, so `OrganicPillButton` (which carries one) doesn't
    /// fit — but the same terracotta capsule it draws.
    private var subscribeButton: some View {
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
                        .tint(.white)
                } else {
                    VStack(spacing: 2) {
                        Text("Start Free Trial")
                            .font(.system(size: 17, weight: .bold, design: .serif))
                        Text("7 days free, then auto-renews")
                            .font(.system(size: 12))
                            .opacity(0.85)
                    }
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Capsule().fill(OrganicPalette.terracotta(colorScheme)))
        }
        .buttonStyle(.plain)
        .disabled(subscriptionManager.isPurchasing)
        .opacity(subscriptionManager.isPurchasing ? 0.7 : 1)
        .padding(.horizontal, 20)
    }

    // MARK: - Legal

    private var legal: some View {
        VStack(spacing: 8) {
            Text("Subscription renews automatically unless cancelled at least 24 hours before the end of the current period. Manage or cancel anytime in App Store Settings.")
                .font(.system(size: 12))
                .foregroundColor(OrganicPalette.inkSoft(colorScheme))
                .multilineTextAlignment(.center)

            HStack(spacing: 16) {
                Link("Terms of Use", destination: appleEULAURL)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(OrganicPalette.terracotta(colorScheme))

                Text("\u{00B7}")
                    .font(.system(size: 12))
                    .foregroundColor(OrganicPalette.inkSoft(colorScheme))

                Button("Privacy Policy") { showPrivacy = true }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(OrganicPalette.terracotta(colorScheme))
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
    }
}

#Preview {
    SubscriptionPaywallView()
}
