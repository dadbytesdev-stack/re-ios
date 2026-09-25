import Foundation
import StoreKit

@MainActor
final class StoreKitService: ObservableObject {
    @Published var products: [Product] = []
    @Published var purchasedProductIds: Set<String> = []
    @Published var isLoading = false

    /// Non-consumable: bought once, never expires.
    ///
    /// Not com.recipeextractor.lifetime — that id was created in App Store
    /// Connect as a non-renewing subscription, which is the wrong type for
    /// permanent access: StoreKit reports it as .nonRenewable (so the paywall
    /// would label a one-time purchase "/ month") and, more seriously, leaves
    /// it out of Transaction.currentEntitlements entirely, so Restore
    /// Purchases could never find it. A product's type cannot be changed after
    /// creation and an id can never be reused, hence the new id.
    static let lifetimeProductId = "com.recipeextractor.pro.lifetime"

    /// Products offered on the paywall, cheapest first.
    ///
    /// com.recipeextractor.pro.yearly is deliberately absent — it is no longer
    /// sold now that Lifetime exists. Anyone already on it keeps it: removing a
    /// product from this list only stops it being offered, it does not revoke
    /// an active subscription, and `entitlementPriority` below still ranks it.
    static let productIds: Set<String> = [
        "com.recipeextractor.premium.monthly",
        "com.recipeextractor.pro.monthly",
        lifetimeProductId
    ]

    /// Higher wins when someone holds more than one entitlement — a lifetime
    /// buyer who also has a lapsing subscription must be reported as Lifetime,
    /// not downgraded to whatever Transaction.currentEntitlements yields first.
    private static func entitlementPriority(_ productId: String) -> Int {
        switch productId {
        case lifetimeProductId: return 3
        case "com.recipeextractor.pro.monthly", "com.recipeextractor.pro.yearly": return 2
        case "com.recipeextractor.premium.monthly": return 1
        default: return 0
        }
    }

    /// True once the lifetime unlock has been purchased. Drives the paywall,
    /// which must not offer a one-time purchase to someone who already owns it.
    var hasLifetime: Bool { purchasedProductIds.contains(Self.lifetimeProductId) }

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

    /// The best current entitlement as a JWS the backend can re-verify on
    /// restore.
    ///
    /// `Transaction.currentEntitlements` has no defined order, so with both a
    /// lifetime unlock and a subscription present, taking the first match
    /// could restore the lesser of the two. Rank them and send the highest.
    func currentEntitlementJWS() async -> (productId: String, jws: String)? {
        var best: (productId: String, jws: String, rank: Int)?
        for await result in Transaction.currentEntitlements {
            guard case .verified(let tx) = result, tx.revocationDate == nil else { continue }
            let rank = Self.entitlementPriority(tx.productID)
            if best == nil || rank > best!.rank {
                best = (tx.productID, result.jwsRepresentation, rank)
            }
        }
        guard let best else { return nil }
        return (best.productId, best.jws)
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
