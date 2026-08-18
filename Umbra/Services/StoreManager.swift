// StoreManager.swift
// Umbra — Privacy-First Browser

import Combine
import Foundation
import StoreKit

enum UmbraTier: String, CaseIterable {
    case shadow = "shadow"       // Free
    case eclipse = "eclipse"     // Pro subscription
    case void_ = "void"          // Lifetime

    var displayName: String {
        switch self {
        case .shadow: return "Shadow"
        case .eclipse: return "Eclipse"
        case .void_: return "Eclipse Lifetime"
        }
    }
}

@MainActor
final class StoreManager: ObservableObject {
    static let shared = StoreManager()

    // ──────────────────────────────────────────────
    // TEMPORARY: Set to true to make all features free.
    // Flip back to false to restore normal subscription behaviour.
    // ──────────────────────────────────────────────
    static let allFeaturesUnlocked = true

    // Product IDs
    static let eclipseMonthlyID = "com.umbra.browser.eclipse.monthly"
    static let eclipseYearlyID = "com.umbra.browser.eclipse.yearly"
    static let voidLifetimeID = "com.umbra.browser.eclipse.lifetime"

    static let allProductIDs: Set<String> = [
        eclipseMonthlyID, eclipseYearlyID, voidLifetimeID
    ]

    // Published state
    @Published var products: [Product] = []
    @Published var purchasedProductIDs: Set<String> = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    // Current tier
    var currentTier: UmbraTier {
        if Self.allFeaturesUnlocked { return .void_ }
        if purchasedProductIDs.contains(StoreManager.voidLifetimeID) {
            return .void_
        }
        if purchasedProductIDs.contains(StoreManager.eclipseMonthlyID) ||
           purchasedProductIDs.contains(StoreManager.eclipseYearlyID) {
            return .eclipse
        }
        return .shadow
    }

    var isPro: Bool {
        if Self.allFeaturesUnlocked { return true }
        return currentTier != .shadow
    }

    // Sorted products for display
    var eclipseMonthly: Product? {
        products.first { $0.id == StoreManager.eclipseMonthlyID }
    }

    var eclipseYearly: Product? {
        products.first { $0.id == StoreManager.eclipseYearlyID }
    }

    var voidLifetime: Product? {
        products.first { $0.id == StoreManager.voidLifetimeID }
    }

    private var transactionListener: Task<Void, Error>?

    init() {
        transactionListener = listenForTransactions()
        Task { await loadProducts() }
        Task { await updatePurchasedProducts() }
    }

    deinit {
        transactionListener?.cancel()
    }

    // MARK: - Load Products

    func loadProducts() async {
        isLoading = true
        errorMessage = nil

        do {
            let storeProducts = try await Product.products(for: StoreManager.allProductIDs)
            products = storeProducts.sorted { $0.price < $1.price }
        } catch {
            errorMessage = "Failed to load products: \(error.localizedDescription)"
            print("[Umbra] StoreKit error: \(error)")
        }

        isLoading = false
    }

    // MARK: - Purchase

    func purchase(_ product: Product) async throws -> StoreKit.Transaction? {
        isLoading = true
        errorMessage = nil

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await updatePurchasedProducts()
                await transaction.finish()
                isLoading = false
                return transaction

            case .userCancelled:
                isLoading = false
                return nil

            case .pending:
                isLoading = false
                errorMessage = "Purchase is pending approval."
                return nil

            @unknown default:
                isLoading = false
                return nil
            }
        } catch {
            isLoading = false
            errorMessage = "Purchase failed: \(error.localizedDescription)"
            throw error
        }
    }

    // MARK: - Restore

    func restorePurchases() async {
        isLoading = true
        errorMessage = nil

        do {
            try await AppStore.sync()
            await updatePurchasedProducts()
        } catch {
            errorMessage = "Restore failed: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - Transaction Listener

    private func listenForTransactions() -> Task<Void, Error> {
        Task.detached {
            for await result in StoreKit.Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)
                    await self.updatePurchasedProducts()
                    await transaction.finish()
                } catch {
                    print("[Umbra] Transaction verification failed: \(error)")
                }
            }
        }
    }

    // MARK: - Update Purchased Products

    func updatePurchasedProducts() async {
        var purchased: Set<String> = []

        // Check active subscriptions
        for await result in StoreKit.Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)

                switch transaction.productType {
                case .autoRenewable:
                    if transaction.revocationDate == nil {
                        purchased.insert(transaction.productID)
                    }
                case .nonConsumable:
                    if transaction.revocationDate == nil {
                        purchased.insert(transaction.productID)
                    }
                default:
                    break
                }
            } catch {
                print("[Umbra] Entitlement verification failed: \(error)")
            }
        }

        self.purchasedProductIDs = purchased
    }

    // MARK: - Verification

    private nonisolated func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let value):
            return value
        }
    }

    // MARK: - Manage Subscription

    func manageSubscription() async {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        do {
            try await AppStore.showManageSubscriptions(in: scene)
        } catch {
            print("[Umbra] Failed to show manage subscriptions: \(error)")
        }
    }
}
