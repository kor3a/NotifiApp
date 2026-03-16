//
//  SubscriptionManager.swift
//  Geolocation_v1.0.0
//
//  Manages StoreKit 2 subscription purchases and status.
//

import Foundation
import StoreKit
import FirebaseFirestore

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

    private init() {
        updateListenerTask = listenForTransactionUpdates()
        Task {
            await loadProducts()
            await refreshSubscriptionStatus()
        }
    }

    deinit {
        updateListenerTask?.cancel()
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
        var hasActiveSubscription = false

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            if transaction.productID == Self.monthlyProductID,
               transaction.revocationDate == nil {
                hasActiveSubscription = true
                break
            }
        }

        isSubscribed = hasActiveSubscription
        syncSubscriptionStatus(isSubscribed: hasActiveSubscription)
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

    private func syncSubscriptionStatus(isSubscribed: Bool) {
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
