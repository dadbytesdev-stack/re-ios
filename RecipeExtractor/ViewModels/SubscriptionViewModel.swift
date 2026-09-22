import Foundation
import StoreKit

@MainActor
final class SubscriptionViewModel: ObservableObject {
    @Published var usage: UsageResponse?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    private let api = APIService.shared
    private let storeKit: StoreKitService
    private let authService: AuthService

    init(storeKit: StoreKitService, authService: AuthService) {
        self.storeKit = storeKit
        self.authService = authService
    }

    func loadUsage() async {
        usage = try? await api.getUsage()
    }

    func purchase(_ product: Product) async {
        isLoading = true
        errorMessage = nil
        successMessage = nil
        defer { isLoading = false }

        do {
            guard let result = try await storeKit.purchase(product) else { return }
            let tier = try await api.verifyAppleIAP(
                signedTransaction: result.jws,
                productId: product.id
            )
            authService.updateTier(tier)
            await loadUsage()
            successMessage = "You now have \(tier.displayName) access!"
        } catch let error as AppError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "Purchase failed: \(error.localizedDescription)"
        }
    }

    func restorePurchases() async {
        isLoading = true
        errorMessage = nil
        successMessage = nil
        defer { isLoading = false }

        do {
            try await storeKit.restorePurchases()
            guard let entitlement = await storeKit.currentEntitlementJWS() else {
                successMessage = "No active purchases found."
                return
            }
            let tier = try await api.verifyAppleIAP(
                signedTransaction: entitlement.jws,
                productId: entitlement.productId
            )
            authService.updateTier(tier)
            await loadUsage()
            successMessage = "Purchases restored successfully!"
        } catch let error as AppError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "Restore failed: \(error.localizedDescription)"
        }
    }
}
