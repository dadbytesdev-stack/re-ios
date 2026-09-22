import Foundation
import StoreKit

@MainActor
final class StoreKitService: ObservableObject {
    @Published var products: [Product] = []
    @Published var purchasedProductIds: Set<String> = []
    @Published var isLoading = false

    static let productIds: Set<String> = [
        "com.recipeextractor.premium.monthly",
        "com.recipeextractor.pro.monthly",
        "com.recipeextractor.pro.yearly"
    ]

    private var updateListenerTask: Task<Void, Error>?

    init() {
        updateListenerTask = listenForTransactions()
        Task { await updatePurchasedProducts() }
    }

    deinit { updateListenerTask?.cancel() }

    func loadProducts() async {
        do {
            products = try await Product.products(for: Self.productIds)
                .sorted { $0.price < $1.price }
        } catch {
            print("[StoreKit] Failed to load products: \(error)")
        }
    }

    /// Returns both the unwrapped Transaction (for client-side state) and the
    /// raw JWS string the backend needs to cryptographically verify the
    /// purchase with Apple's root CAs.
    func purchase(_ product: Product) async throws -> (transaction: Transaction, jws: String)? {
        isLoading = true
        defer { isLoading = false }

        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            let jws = verification.jwsRepresentation
            await updatePurchasedProducts()
            await transaction.finish()
            return (transaction, jws)
        case .userCancelled, .pending:
            return nil
        @unknown default:
            return nil
        }
    }

    func restorePurchases() async throws {
        try await AppStore.sync()
        await updatePurchasedProducts()
    }

    /// The current, verified entitlement (if any) as a JWS the backend can
    /// re-verify on restore. We pick the first verified, non-revoked
    /// transaction in `Transaction.currentEntitlements` — fine for a
    /// single-subscription-group app like this one.
    func currentEntitlementJWS() async -> (productId: String, jws: String)? {
        for await result in Transaction.currentEntitlements {
            if case .verified(let tx) = result, tx.revocationDate == nil {
                return (tx.productID, result.jwsRepresentation)
            }
        }
        return nil
    }

    func updatePurchasedProducts() async {
        var ids = Set<String>()
        for await result in Transaction.currentEntitlements {
            if case .verified(let tx) = result, tx.revocationDate == nil {
                ids.insert(tx.productID)
            }
        }
        purchasedProductIds = ids
    }

    private func listenForTransactions() -> Task<Void, Error> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                do {
                    let transaction = try self.checkVerified(result)
                    await self.updatePurchasedProducts()
                    await transaction.finish()
                } catch {
                    print("[StoreKit] Transaction update error: \(error)")
                }
            }
        }
    }

    nonisolated private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified: throw StoreKitError.failedVerification
        case .verified(let value): return value
        }
    }
}

enum StoreKitError: Error {
    case failedVerification
    case productNotFound
}
