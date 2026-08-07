//
//  SubscriptionManager.swift
//  Geolocation_v1.0.0
//
//  Manages StoreKit 2 subscription purchases and status.
//

import Foundation
import StoreKit
import FirebaseFirestore
import Combine

@MainActor
class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()

    // MARK: - Product IDs
    static let monthlyProductID = "com.kor3a.nearbuy.premium.monthly"
    static let annualProductID  = "com.kor3a.nearbuy.premium.annual"

    // MARK: - Free Tier Limits

    /// Maximum number of stores a non-subscribed account may create for itself.
    ///
    /// This is the only free-tier quota. Items within a store are unlimited on
    /// every tier, and stores shared by another user can always be accepted.
    static let freeStoreLimit = 3

    /// Whether a user may add another store to their list *themselves*.
    ///
    /// The check is made against the CURRENT count at add time, so existing
    /// users who already exceed the limit are grandfathered in: they keep all
    /// their stores, but adding one more requires a subscription.
    ///
    /// This governs self-service adds only. Stores shared by a friend or family
    /// member can always be accepted, even past the limit — see
    /// `MessagingService.acceptSharedStore`. Those accepted stores still count
    /// toward `currentStoreCount` here, so a free user who is above the limit
    /// from shares cannot add any of their own until they drop back under it.
    static func canAddStore(isSubscribed: Bool, currentStoreCount: Int) -> Bool {
        return isSubscribed || currentStoreCount < freeStoreLimit
    }

    // MARK: - Published State
    @Published var isSubscribed: Bool = false
    @Published var product: Product? = nil
    @Published var annualProduct: Product? = nil
    @Published var activeProductID: String? = nil
    @Published var isPurchasing: Bool = false
    @Published var errorMessage: String? = nil

    /// The StoreKit Product the user is currently entitled to, or nil if not subscribed.
    var activeProduct: Product? {
        guard isSubscribed else { return nil }
        switch activeProductID {
        case Self.annualProductID:  return annualProduct
        case Self.monthlyProductID: return product
        default:                    return product
        }
    }

    private var updateListenerTask: Task<Void, Never>? = nil
    private var userCancellable: AnyCancellable? = nil

    private init() {
        updateListenerTask = listenForTransactionUpdates()
        Task {
            await loadProducts()
            await refreshSubscriptionStatus()
        }

        // Re-check status whenever the user loads or changes.
        // This is critical for the adminSubscribed override: on app launch
        // currentUser is nil when SubscriptionManager first runs, so the
        // admin check would be missed without this observer.
        //
        // IMPORTANT: StoreKit entitlements are scoped to the Apple ID, not the
        // app-level user account. If multiple app accounts share the same Apple ID
        // on one device (e.g. during testing), naively querying StoreKit on every
        // login would grant the previous user's subscription to the newly-logged-in
        // user and corrupt their Firestore record. We only call refreshSubscriptionStatus()
        // (which queries StoreKit and syncs to Firestore) when Firestore already shows
        // this user is subscribed — confirming the purchase belongs to them.
        userCancellable = UserSessionManager.shared.$currentUser
            .dropFirst()                      // skip the initial nil
            .removeDuplicates { $0?.userId == $1?.userId }
            .sink { [weak self] user in
                guard let self = self else { return }
                guard let user = user else {
                    // User logged out — clear subscription state immediately.
                    Task { @MainActor [weak self] in
                        self?.isSubscribed = false
                        self?.activeProductID = nil
                    }
                    return
                }
                let hasFirestoreSubscription = user.isSubscribed == true
                let hasAdminOverride = user.adminSubscribed == true
                if hasFirestoreSubscription || hasAdminOverride {
                    // Firestore confirms this user has a subscription — safe to query
                    // StoreKit for live status and active plan details.
                    Task { [weak self] in
                        await self?.refreshSubscriptionStatus()
                    }
                } else {
                    // Firestore says not subscribed. Do NOT query StoreKit here —
                    // any active entitlement belongs to a different app account sharing
                    // the same Apple ID, not this user.
                    Task { @MainActor [weak self] in
                        self?.isSubscribed = false
                        self?.activeProductID = nil
                    }
                }
            }
    }

    deinit {
        updateListenerTask?.cancel()
        userCancellable?.cancel()
    }

    // MARK: - Testable Helpers

    /// Returns `true` if the given transaction token is consistent with the
    /// current user owning the entitlement.
    ///
    /// - `nil` transactionToken → legacy purchase (no token recorded); allow through.
    /// - matching tokens → definitely this user's purchase.
    /// - mismatched tokens → belongs to a different app account sharing the Apple ID.
    static func transactionTokenBelongsToUser(transactionToken: UUID?, userToken: UUID?) -> Bool {
        guard let txToken = transactionToken else { return true }   // legacy: no token set
        guard let userTok = userToken        else { return false }  // new tx but user has no token
        return txToken == userTok
    }

    /// Returns `true` if StoreKit should be queried for a user who just logged in.
    /// We only query StoreKit when Firestore already shows the user has a subscription,
    /// preventing entitlements from leaking to non-subscribing accounts.
    static func shouldQueryStoreKit(for user: User) -> Bool {
        return user.isSubscribed == true || user.adminSubscribed == true
    }

    // MARK: - Load Products

    func loadProducts() async {
        do {
            let products = try await Product.products(for: [Self.monthlyProductID, Self.annualProductID])
            self.product        = products.first { $0.id == Self.monthlyProductID }
            self.annualProduct  = products.first { $0.id == Self.annualProductID }
        } catch {
            #if DEBUG
            print("SubscriptionManager: Failed to load products — \(error.localizedDescription)")
            #endif
        }
    }

    // MARK: - Purchase

    /// Purchase a specific product (monthly or annual).
    func purchase(_ productToBuy: Product) async {
        isPurchasing = true
        errorMessage = nil
        do {
            // Attach the user's subscriptionToken as appAccountToken so StoreKit
            // records which app-level account made this purchase. This lets us
            // later verify that an entitlement belongs to the currently logged-in
            // user rather than another account sharing the same Apple ID.
            var purchaseOptions: Set<Product.PurchaseOption> = []
            if let tokenString = UserSessionManager.shared.currentUser?.subscriptionToken,
               let token = UUID(uuidString: tokenString) {
                purchaseOptions.insert(.appAccountToken(token))
            }
            let result = try await productToBuy.purchase(options: purchaseOptions)
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                await refreshSubscriptionStatus()
            case .userCancelled:
                break
            case .pending:
                errorMessage = "Your purchase is pending approval."
            @unknown default:
                break
            }
        } catch {
            errorMessage = "Purchase failed: \(error.localizedDescription)"
        }
        isPurchasing = false
    }

    /// Convenience: purchase the monthly plan, loading products first if needed.
    func purchase() async {
        if product == nil { await loadProducts() }
        guard let product else {
            errorMessage = "Subscription unavailable. Please check your internet connection and try again."
            return
        }
        await purchase(product)
    }

    // MARK: - Restore Purchases

    func restorePurchases() async {
        isPurchasing = true
        errorMessage = nil
        do {
            try await AppStore.sync()
            await refreshSubscriptionStatus()
        } catch {
            errorMessage = "Restore failed: \(error.localizedDescription)"
        }
        isPurchasing = false
    }

    // MARK: - Subscription Status

    func refreshSubscriptionStatus() async {
        var hasStoreKitSubscription = false
        var subscribedProductID: String? = nil
        let validIDs: Set<String> = [Self.monthlyProductID, Self.annualProductID]

        let currentUserToken = UserSessionManager.shared.currentUser?.subscriptionToken
            .flatMap { UUID(uuidString: $0) }

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            if validIDs.contains(transaction.productID),
               transaction.revocationDate == nil {
                // If the transaction carries an appAccountToken, verify it matches
                // the current user. Legacy purchases (no token) are allowed through
                // — they're already gated upstream by the Firestore check in the
                // user-change observer.
                guard Self.transactionTokenBelongsToUser(
                    transactionToken: transaction.appAccountToken,
                    userToken: currentUserToken
                ) else { continue }
                hasStoreKitSubscription = true
                subscribedProductID = transaction.productID
                break
            }
        }

        // adminSubscribed is set manually in Firestore and never overwritten by the app.
        // This lets you grant free access to yourself or testers without Apple payment.
        let hasAdminOverride = UserSessionManager.shared.currentUser?.adminSubscribed == true

        isSubscribed = hasStoreKitSubscription || hasAdminOverride
        activeProductID = hasStoreKitSubscription ? subscribedProductID : nil

        // Only sync StoreKit-derived status to Firestore.
        // Never touch adminSubscribed — it's managed manually.
        if hasStoreKitSubscription {
            syncStoreKitStatus(isSubscribed: true)
        } else if !hasAdminOverride {
            // Only write false when there's no admin override protecting the field
            syncStoreKitStatus(isSubscribed: false)
        }
    }

    // MARK: - Transaction Listener

    private func listenForTransactionUpdates() -> Task<Void, Never> {
        Task(priority: .background) { [weak self] in
            for await result in Transaction.updates {
                guard let self = self else { break }
                do {
                    let transaction = try self.checkVerified(result)

                    // If the renewal/update has an appAccountToken, only process it
                    // for the matching user. This prevents User A's auto-renewal from
                    // updating User B's Firestore record when B is currently logged in.
                    // Finish the transaction regardless — StoreKit requires it.
                    if let txToken = transaction.appAccountToken {
                        let currentUserToken = UserSessionManager.shared.currentUser?.subscriptionToken
                            .flatMap { UUID(uuidString: $0) }
                        guard txToken == currentUserToken else {
                            await transaction.finish()
                            continue
                        }
                    }

                    await self.refreshSubscriptionStatus()
                    await transaction.finish()
                } catch {
                    #if DEBUG
                    print("SubscriptionManager: Unverified transaction — \(error.localizedDescription)")
                    #endif
                }
            }
        }
    }

    // MARK: - Verification Helper

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let value):
            return value
        }
    }

    // MARK: - Firebase Sync

    /// Syncs StoreKit-derived subscription status to Firestore.
    /// Never touches `adminSubscribed` — that field is managed manually in the Firebase console.
    private func syncStoreKitStatus(isSubscribed: Bool) {
        guard let userId = UserSessionManager.shared.currentUser?.userId else { return }

        let db = Firestore.firestore()
        db.collection("users").document(userId).updateData([
            "isSubscribed": isSubscribed
        ]) { error in
            #if DEBUG
            if let error = error {
                print("SubscriptionManager: Failed to sync status — \(error.localizedDescription)")
            } else {
                print("SubscriptionManager: Synced isSubscribed=\(isSubscribed)")
            }
            #endif
        }

        if var user = UserSessionManager.shared.currentUser {
            user.isSubscribed = isSubscribed
            UserSessionManager.shared.currentUser = user
        }
    }
}
