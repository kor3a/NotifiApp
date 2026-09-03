//
//  SubscriptionDebugView.swift
//  Geolocation_v1.0.0
//
//  Debug-only view for manually verifying subscription isolation across
//  multiple app accounts sharing the same Apple ID on one device.
//
//  Access: ProfileView → Debug section → "Subscription Debug"
//

#if DEBUG
import SwiftUI
import StoreKit

struct SubscriptionDebugView: View {

    @ObservedObject private var sub     = SubscriptionManager.shared
    @ObservedObject private var session = UserSessionManager.shared

    @State private var entitlements: [EntitlementEntry] = []
    @State private var isLoadingEntitlements = false

    struct EntitlementEntry: Identifiable {
        let id = UUID()
        let productID: String
        let appAccountToken: UUID?
        let isRevoked: Bool
    }

    var body: some View {
        List {
            // ── App user (from Firestore) ─────────────────────────────────
            Section("App User (Firestore)") {
                if let user = session.currentUser {
                    row("userId",              value: user.userId)
                    row("isSubscribed",        value: describe(user.isSubscribed))
                    row("adminSubscribed",     value: describe(user.adminSubscribed))
                    row("subscriptionToken",   value: user.subscriptionToken ?? "nil (legacy — no token yet)")
                } else {
                    Text("No user logged in").foregroundStyle(Color.secondaryText)
                }
            }

            // ── SubscriptionManager state (in memory) ─────────────────────
            Section("SubscriptionManager (In-Memory)") {
                HStack {
                    Text("isSubscribed")
                    Spacer()
                    Text(sub.isSubscribed ? "true ✓" : "false")
                        .foregroundStyle(sub.isSubscribed ? Color.appSuccess : Color.primaryText)
                        .fontWeight(sub.isSubscribed ? .semibold : .regular)
                }
                row("activeProductID", value: sub.activeProductID ?? "nil")
            }

            // ── StoreKit entitlements (Apple-ID-scoped) ───────────────────
            Section {
                if isLoadingEntitlements {
                    ProgressView("Loading StoreKit entitlements…")
                } else if entitlements.isEmpty {
                    Text("No active entitlements on this Apple ID")
                        .foregroundStyle(Color.secondaryText)
                } else {
                    ForEach(entitlements) { entry in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(entry.productID)
                                .font(.caption.monospaced())
                                .bold()

                            HStack(alignment: .top) {
                                Text("appAccountToken:")
                                    .foregroundStyle(Color.secondaryText)
                                    .font(.caption2)
                                Text(entry.appAccountToken.map { $0.uuidString } ?? "nil  (legacy — no token)")
                                    .font(.caption2.monospaced())
                                    .lineLimit(2)
                            }

                            ownershipBadge(for: entry)
                        }
                        .padding(.vertical, 2)
                    }
                }

                Button("Reload StoreKit Entitlements") {
                    Task { await loadEntitlements() }
                }
            } header: {
                Text("StoreKit Entitlements (Apple-ID-scoped)")
            } footer: {
                Text("Entitlements are tied to the Apple ID, not the app user. The subscriptionToken links them to a specific account.")
                    .font(.caption)
            }

            // ── Actions ───────────────────────────────────────────────────
            Section("Actions") {
                Button("Re-run refreshSubscriptionStatus()") {
                    Task { await SubscriptionManager.shared.refreshSubscriptionStatus() }
                }
            }

            // ── Manual test checklist ─────────────────────────────────────
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    step(1, "Log in as User A → subscribe → confirm isSubscribed=true above")
                    step(2, "Log out as User A")
                    step(3, "Log in as User B → confirm isSubscribed=false above")
                    step(4, "Check Firebase Console — User B's document must NOT have isSubscribed=true")
                    step(5, "Log back in as User A → confirm isSubscribed=true is restored")
                    step(6, "Check StoreKit entitlement above — token should match User A's subscriptionToken, NOT User B's")
                }
                .font(.caption)
                .foregroundStyle(Color.secondaryText)
            } header: {
                Text("Multi-User Isolation Checklist")
            }
        }
        .navigationTitle("Subscription Debug")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadEntitlements() }
    }

    // MARK: - Helpers

    private func row(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundStyle(Color.secondaryText)
                .font(.caption.monospaced())
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    private func describe(_ flag: Bool?) -> String {
        switch flag {
        case .some(true):  return "true"
        case .some(false): return "false"
        case .none:        return "nil"
        }
    }

    @ViewBuilder
    private func ownershipBadge(for entry: EntitlementEntry) -> some View {
        let userTokenString = session.currentUser?.subscriptionToken
        let belongs = SubscriptionManager.transactionTokenBelongsToUser(
            transactionToken: entry.appAccountToken,
            userToken: userTokenString.flatMap { UUID(uuidString: $0) }
        )
        HStack(spacing: 4) {
            Image(systemName: belongs ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(belongs ? Color.appSuccess : Color.appError)
            Text(belongs
                 ? (entry.appAccountToken == nil ? "Legacy purchase — gated by Firestore" : "Belongs to current user ✓")
                 : "BELONGS TO A DIFFERENT USER — will be ignored")
                .font(.caption2)
                .foregroundStyle(belongs ? Color.appSuccess : Color.appError)
        }
    }

    private func step(_ n: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text("\(n).")
                .monospacedDigit()
            Text(text)
        }
    }

    private func loadEntitlements() async {
        isLoadingEntitlements = true
        var result: [EntitlementEntry] = []
        for await item in Transaction.currentEntitlements {
            if case .verified(let tx) = item {
                result.append(EntitlementEntry(
                    productID: tx.productID,
                    appAccountToken: tx.appAccountToken,
                    isRevoked: tx.revocationDate != nil
                ))
            }
        }
        entitlements = result
        isLoadingEntitlements = false
    }
}

#Preview {
    NavigationStack {
        SubscriptionDebugView()
    }
}
#endif
