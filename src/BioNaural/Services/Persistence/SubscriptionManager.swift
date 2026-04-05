// SubscriptionManager.swift
// BioNaural
//
// StoreKit 2 subscription state manager. Handles purchasing, entitlement
// verification, transaction observation, and offline caching. Single source
// of truth for premium status across the app.

import Foundation
import StoreKit
import Observation

// MARK: - Product Identifiers

enum SubscriptionProduct {
    static let monthly = "com.bionaural.monthly"
    static let annual = "com.bionaural.annual"
    static let lifetime = "com.bionaural.lifetime"

    static let all: [String] = [monthly, annual, lifetime]

    /// Subscription product IDs only (excludes lifetime non-consumable).
    static let autoRenewable: [String] = [monthly, annual]
}

// MARK: - Cached Entitlement

/// Lightweight entitlement snapshot persisted to UserDefaults for offline access.
/// Never used as the authoritative source when StoreKit is reachable.
private struct CachedEntitlement: Codable {
    let isPremium: Bool
    let productID: String?
    let expirationDate: Date?
    let lastVerifiedDate: Date

    static let storageKey = "com.bionaural.cachedEntitlement"
}

// MARK: - SubscriptionManager

@MainActor
@Observable
final class SubscriptionManager {

    // MARK: - Published State

    /// Whether the user currently has premium access (subscription or lifetime).
    private(set) var isPremium: Bool = false

    /// The currently active subscription product, if any.
    /// `nil` for lifetime purchases or free-tier users.
    private(set) var currentSubscription: Product?

    /// Expiration date for the current subscription period.
    /// `nil` for lifetime purchases or free-tier users.
    private(set) var expirationDate: Date?

    /// All available products fetched from the App Store.
    private(set) var products: [Product] = []

    /// Loading state for product fetch.
    private(set) var isLoadingProducts: Bool = false

    /// Error from the most recent operation, cleared on next attempt.
    private(set) var lastError: Error?

    // MARK: - Private

    /// Background task listening for transaction updates (renewals, refunds, etc.).
    nonisolated(unsafe) private var transactionListenerTask: Task<Void, Never>?

    // MARK: - Singleton

    static let shared = SubscriptionManager()

    // MARK: - Initialization

    private init() {
        // Restore cached entitlement for immediate offline access.
        loadCachedEntitlement()

        // Start observing transaction updates from StoreKit.
        transactionListenerTask = listenForTransactionUpdates()

        // Verify current entitlement against StoreKit on launch.
        Task { [weak self] in
            await self?.loadProducts()
            _ = await self?.checkEntitlement()
        }
    }

    deinit {
        let task = transactionListenerTask
        task?.cancel()
    }

    // MARK: - Product Loading

    /// Fetches available products from the App Store.
    func loadProducts() async {
        isLoadingProducts = true
        lastError = nil

        do {
            let storeProducts = try await Product.products(for: SubscriptionProduct.all)

            // Sort: monthly, annual, lifetime (by price ascending).
            products = storeProducts.sorted { $0.price < $1.price }
        } catch {
            lastError = error
        }

        isLoadingProducts = false
    }

    // MARK: - Purchase

    /// Initiates a purchase for the given product.
    ///
    /// - Parameter product: The StoreKit `Product` to purchase.
    /// - Returns: The verified `Transaction` on success.
    /// - Throws: `StoreKit.Product.PurchaseError` or verification errors.
    @discardableResult
    func purchase(product: Product) async throws -> Transaction {
        lastError = nil

        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            let transaction = try checkVerification(verification)

            // Finish the transaction so the App Store knows we delivered.
            await transaction.finish()

            // Refresh entitlement state.
            _ = await checkEntitlement()

            return transaction

        case .userCancelled:
            throw PurchaseError.cancelled

        case .pending:
            // Ask to Buy, Strong Customer Authentication, etc.
            throw PurchaseError.pending

        @unknown default:
            throw PurchaseError.unknown
        }
    }

    // MARK: - Restore Purchases

    /// Triggers a sync with the App Store to restore previous purchases.
    /// Useful when a user switches devices or reinstalls.
    func restorePurchases() async {
        lastError = nil

        do {
            try await AppStore.sync()
            _ = await checkEntitlement()
        } catch {
            lastError = error
        }
    }

    // MARK: - Entitlement Check

    /// Verifies the user's current entitlement by examining all current transactions.
    ///
    /// This is the authoritative entitlement check. It iterates through
    /// `Transaction.currentEntitlements` to find any active subscription or
    /// lifetime purchase.
    ///
    /// - Returns: `true` if the user has premium access.
    @discardableResult
    func checkEntitlement() async -> Bool {
        var foundPremium = false
        var foundSubscription: Product?
        var foundExpiration: Date?

        for await result in Transaction.currentEntitlements {
            guard let transaction = try? checkVerification(result) else {
                continue
            }

            // Check for revoked (refunded) transactions.
            if transaction.revocationDate != nil {
                continue
            }

            switch transaction.productID {
            case SubscriptionProduct.lifetime:
                // Lifetime purchase — premium forever.
                foundPremium = true
                foundSubscription = nil
                foundExpiration = nil

            case SubscriptionProduct.monthly, SubscriptionProduct.annual:
                // Active auto-renewable subscription.
                // Check grace period and billing retry state.
                if let expiration = transaction.expirationDate {
                    // StoreKit 2 includes grace period time in the expiration date
                    // when the subscription is in a billing retry state. The
                    // transaction remains in currentEntitlements during the grace
                    // period, so we treat it as active.
                    if expiration > Date() {
                        foundPremium = true
                        foundExpiration = expiration

                        // Resolve the product object for display purposes.
                        if foundSubscription == nil {
                            foundSubscription = products.first {
                                $0.id == transaction.productID
                            }
                        }
                    }
                }

            default:
                break
            }
        }

        // Update published state.
        isPremium = foundPremium
        currentSubscription = foundSubscription
        expirationDate = foundExpiration

        // Cache for offline access.
        cacheEntitlement()

        return foundPremium
    }

    // MARK: - Transaction Listener

    /// Listens for real-time transaction updates: renewals, cancellations,
    /// refunds, revocations, and Family Sharing changes.
    private func listenForTransactionUpdates() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                guard let transaction = try? await self.checkVerification(result) else {
                    continue
                }

                // Finish the transaction.
                await transaction.finish()

                // Re-check entitlement on the main actor.
                await MainActor.run {
                    Task { [weak self] in
                        _ = await self?.checkEntitlement()
                    }
                }
            }
        }
    }

    // MARK: - Verification

    /// Unwraps and verifies a StoreKit verification result.
    ///
    /// StoreKit 2 performs automatic JWS verification. This method extracts
    /// the verified payload or throws if verification failed.
    private nonisolated func checkVerification<T>(
        _ result: VerificationResult<T>
    ) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let safe):
            return safe
        }
    }

    // MARK: - Offline Cache

    /// Persists the current entitlement state to UserDefaults.
    private func cacheEntitlement() {
        let cached = CachedEntitlement(
            isPremium: isPremium,
            productID: currentSubscription?.id,
            expirationDate: expirationDate,
            lastVerifiedDate: Date()
        )

        if let data = try? JSONEncoder().encode(cached) {
            UserDefaults.standard.set(data, forKey: CachedEntitlement.storageKey)
        }
    }

    /// Loads the cached entitlement from UserDefaults.
    /// Used only at init for immediate offline access before StoreKit responds.
    private func loadCachedEntitlement() {
        guard let data = UserDefaults.standard.data(
            forKey: CachedEntitlement.storageKey
        ) else { return }

        guard let cached = try? JSONDecoder().decode(
            CachedEntitlement.self,
            from: data
        ) else { return }

        // Apply cached state. Will be overwritten once StoreKit verifies.
        isPremium = cached.isPremium

        // If the cached expiration is in the past, do not trust the cache.
        if let expiration = cached.expirationDate, expiration < Date() {
            isPremium = false
        }

        expirationDate = cached.expirationDate
    }

    // MARK: - Convenience Lookups

    /// Returns the monthly product if loaded.
    var monthlyProduct: Product? {
        products.first { $0.id == SubscriptionProduct.monthly }
    }

    /// Returns the annual product if loaded.
    var annualProduct: Product? {
        products.first { $0.id == SubscriptionProduct.annual }
    }

    /// Returns the lifetime product if loaded.
    var lifetimeProduct: Product? {
        products.first { $0.id == SubscriptionProduct.lifetime }
    }

    // MARK: - Debug Helpers

    /// Overrides premium status for development and testing.
    /// Sets the in-memory flag and updates the offline cache so the
    /// override persists across views. Does not interact with StoreKit.
    func debugSetPremium(_ enabled: Bool) {
        isPremium = enabled
        currentSubscription = nil
        expirationDate = nil
        cacheEntitlement()
    }
}

// MARK: - Purchase Errors

extension SubscriptionManager {

    enum PurchaseError: LocalizedError {
        case cancelled
        case pending
        case unknown

        var errorDescription: String? {
            switch self {
            case .cancelled:
                return "Purchase was cancelled."
            case .pending:
                return "Purchase is pending approval."
            case .unknown:
                return "An unexpected error occurred. Please try again."
            }
        }
    }
}
