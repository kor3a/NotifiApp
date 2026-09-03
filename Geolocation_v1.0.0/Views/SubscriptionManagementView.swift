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

    private var annualSavingsLabel: String? {
        guard let monthly = subscriptionManager.product,
              let annual = subscriptionManager.annualProduct else { return nil }
        let monthlyDouble = NSDecimalNumber(decimal: monthly.price).doubleValue
        let annualDouble  = NSDecimalNumber(decimal: annual.price).doubleValue
        guard monthlyDouble > 0 else { return nil }
        let pct = (monthlyDouble * 12 - annualDouble) / (monthlyDouble * 12) * 100
        return pct > 0 ? "Save \(Int(pct.rounded()))%" : nil
    }

    var body: some View {
        NavigationStack {
            ZStack {
                OrganicPalette.canvas(colorScheme)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 26) {
                        hero

                        featureCard

                        planSection

                        OrganicPillButton(
                            title: "Manage Subscription",
                            systemImage: "gear",
                            fillsWidth: true
                        ) {
                            Task { await openManageSubscriptions() }
                        }
                        .padding(.horizontal, 20)

                        cancelSection

                        legal
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 16)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(OrganicPalette.canvas(colorScheme), for: .navigationBar)
            .tint(OrganicPalette.terracotta(colorScheme))
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundColor(OrganicPalette.terracotta(colorScheme))
                }

                ToolbarItem(placement: .principal) {
                    Text("Subscription")
                        .font(OrganicPalette.title(17))
                        .foregroundColor(OrganicPalette.ink(colorScheme))
                }
            }
            .organicAlert(
                "Unable to Open Settings",
                isPresented: $showManageError,
                icon: "exclamationmark.triangle.fill",
                tone: .destructive,
                message: manageErrorMessage,
                actions: [.ok()]
            )
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

            Text("Active subscription")
                .font(.system(size: 13, weight: .bold))
                .kerning(0.6)
                .textCase(.uppercase)
                .foregroundColor(OrganicPalette.sageInk(colorScheme))
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(Capsule().fill(OrganicPalette.sage(colorScheme)))
        }
    }

    // MARK: - Features

    private var featureCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Your Premium features")
                .font(OrganicPalette.display(20))
                .foregroundColor(OrganicPalette.ink(colorScheme))

            ForEach(PremiumFeature.all) { feature in
                featureRow(
                    icon: feature.icon,
                    title: feature.title,
                    description: feature.description
                )
            }
        }
        .padding(20)
        .background(OrganicCardBackground(colorScheme: colorScheme, cornerRadius: 28))
        .padding(.horizontal, 20)
    }

    /// Matches the paywall's row exactly — the same list, once you own it.
    private func featureRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(OrganicPalette.sageInk(colorScheme))
                .frame(width: 38, height: 38)
                .background(Circle().fill(OrganicPalette.sage(colorScheme)))

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

    // MARK: - Plan

    private var planSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            OrganicSectionLabel(title: "Your plan")

            HStack(spacing: 12) {
                planComparisonCard(
                    title: "Monthly",
                    price: subscriptionManager.product?.displayPrice ?? "—",
                    period: "per month",
                    isActive: subscriptionManager.activeProductID == SubscriptionManager.monthlyProductID,
                    badge: nil
                )
                planComparisonCard(
                    title: "Annual",
                    price: subscriptionManager.annualProduct?.displayPrice ?? "$10.00",
                    period: "per year",
                    isActive: subscriptionManager.activeProductID == SubscriptionManager.annualProductID,
                    badge: annualSavingsLabel
                )
            }
        }
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private func planComparisonCard(title: String, price: String, period: String, isActive: Bool, badge: String?) -> some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 6) {
                if isActive {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                        Text("Current Plan")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(OrganicPalette.onTerracotta(colorScheme))
                }

                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(
                        isActive
                            ? OrganicPalette.onTerracotta(colorScheme)
                            : OrganicPalette.inkSoft(colorScheme)
                    )

                Text(price)
                    .font(OrganicPalette.display(24))
                    .foregroundColor(
                        isActive
                            ? OrganicPalette.onTerracotta(colorScheme)
                            : OrganicPalette.ink(colorScheme)
                    )

                Text(period)
                    .font(.system(size: 13))
                    .foregroundColor(
                        isActive
                            ? OrganicPalette.onTerracotta(colorScheme).opacity(0.8)
                            : OrganicPalette.inkSoft(colorScheme)
                    )
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .padding(.top, badge != nil ? 10 : 0)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        isActive
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

    // MARK: - Cancel

    private var cancelSection: some View {
        VStack(spacing: 8) {
            Button {
                Task { await openManageSubscriptions() }
            } label: {
                Text("Cancel Subscription")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(OrganicPalette.rust(colorScheme))
            }
            .buttonStyle(.plain)

            Text("To cancel, tap above to open App Store subscription settings and turn off auto-renewal for Allim Premium.")
                .font(.system(size: 13))
                .foregroundColor(OrganicPalette.inkSoft(colorScheme))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
    }

    // MARK: - Legal

    private var legal: some View {
        VStack(spacing: 10) {
            let isAnnual = subscriptionManager.activeProduct?.id == SubscriptionManager.annualProductID

            Text("Allim Premium \u{00B7} \(isAnnual ? "Annual" : "Monthly") Subscription")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(OrganicPalette.inkSoft(colorScheme))

            Text("Subscription auto-renews \(isAnnual ? "annually" : "monthly") unless cancelled at least 24 hours before the end of the current period. Manage or cancel anytime in App Store Settings.")
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
}

#Preview {
    SubscriptionManagementView()
}
