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
                            icon: "infinity.circle.fill",
                            color: .orange,
                            title: "Unlimited Stores & Items",
                            description: "Free accounts are limited to \(SubscriptionManager.freeStoreLimit) stores of your own and \(SubscriptionManager.freeReminderLimitPerStore) items per store — go unlimited with Premium"
                        )
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

                    // Plan comparison
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Your Plan")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)

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

    @ViewBuilder
    private func planComparisonCard(title: String, price: String, period: String, isActive: Bool, badge: String?) -> some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 6) {
                if isActive {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                        Text("Current Plan")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                }
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(isActive ? .white : .primary)
                Text(price)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(isActive ? .white : .primary)
                Text(period)
                    .font(.caption)
                    .foregroundColor(isActive ? .white.opacity(0.8) : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .padding(.top, badge != nil ? 10 : 0)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isActive
                        ? AnyShapeStyle(LinearGradient(
                            colors: [.yellow, .orange],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing))
                        : AnyShapeStyle(.ultraThinMaterial))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(
                        isActive ? Color.clear : Color.secondary.opacity(0.2),
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
