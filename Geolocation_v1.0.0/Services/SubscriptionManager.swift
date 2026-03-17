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

    // MARK: - Product ID
    static let monthlyProductID = "com.kor3a.nearbuy.premium.monthly"

    // MARK: - Published State
    @Published var isSubscribed: Bool = false
    @Published var product: Product? = nil
    @Published var isPurchasing: Bool = false
    @Published var errorMessage: String? = nil

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
        userCancellable = UserSessionManager.shared.$currentUser
            .dropFirst()                      // skip the initial nil
            .removeDuplicates { $0?.userId == $1?.userId }
            .sink { [weak self] user in
                guard user != nil else { return }
                Task { [weak self] in
                    await self?.refreshSubscriptionStatus()
                }
            }
    }

    deinit {
        updateListenerTask?.cancel()
        userCancellable?.cancel()
    }

    // MARK: - Load Products

    func loadProducts() async {
        do {
            let products = try await Product.products(for: [Self.monthlyProductID])
            self.product = products.first
        } catch {
            #if DEBUG
            print("SubscriptionManager: Failed to load products — \(error.localizedDescription)")
            #endif
        }
    }

    // MARK: - Purchase

    func purchase() async {
        guard let product = product else {
            errorMessage = "Product not available. Please check your connection and try again."
            return
        }

        isPurchasing = true
        errorMessage = nil

        do {
            let result = try await product.purchase()
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

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            if transaction.productID == Self.monthlyProductID,
               transaction.revocationDate == nil {
                hasStoreKitSubscription = true
                break
            }
        }

        // adminSubscribed is set manually in Firestore and never overwritten by the app.
        // This lets you grant free access to yourself or testers without Apple payment.
        let hasAdminOverride = UserSessionManager.shared.currentUser?.adminSubscribed == true

        isSubscribed = hasStoreKitSubscription || hasAdminOverride

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
