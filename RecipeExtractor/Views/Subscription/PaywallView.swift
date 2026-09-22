import SwiftUI
import StoreKit

struct PaywallView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var storeKit: StoreKitService
    @Environment(\.dismiss) private var dismiss

    @State private var selectedProductId: String?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var successMessage: String?

    private var selectedProduct: Product? {
        storeKit.products.first { $0.id == selectedProductId }
    }

    /// Lifetime is a non-consumable, not a subscription: the call to action,
    /// and the renewal terms below it, have to change accordingly.
    private var selectionIsOneTime: Bool {
        selectedProduct?.type == .nonConsumable
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.orange)
                        Text("Upgrade Your Plan")
                            .font(.title.bold())
                        Text("You're on \(authService.currentUser?.tier.displayName ?? "Free") — here's what more looks like")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 24)

                    // Feature highlights
                    VStack(alignment: .leading, spacing: 12) {
                        FeatureRow(icon: "wand.and.stars",
                                   text: "Premium: \(SubscriptionTier.premium.monthlyLimit ?? 0) extractions a month")
                        FeatureRow(icon: "infinity",
                                   text: "Pro: unlimited extractions, billed monthly")
                        FeatureRow(icon: "checkmark.seal.fill",
                                   text: "Lifetime: unlimited forever, paid once")
                        FeatureRow(icon: "bookmark.fill",
                                   text: "Every plan saves your recipe library")
                    }
                    .padding(.horizontal, 32)

                    // Products
                    if storeKit.hasLifetime {
                        // Nothing left to sell someone who bought the
                        // permanent unlock.
                        VStack(spacing: 8) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.largeTitle).foregroundStyle(.green)
                            Text("You have Lifetime access")
                                .font(.headline)
                            Text("Unlimited extractions, forever. Nothing to renew.")
                                .font(.subheadline).foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal, 32)
                    } else if storeKit.products.isEmpty {
                        ProgressView().padding()
                    } else {
                        VStack(spacing: 12) {
                            ForEach(storeKit.products, id: \.id) { product in
                                ProductCard(
                                    product: product,
                                    isSelected: selectedProductId == product.id,
                                    onSelect: { selectedProductId = product.id }
                                )
                            }
                        }
                        .padding(.horizontal)
                    }

                    // Feedback messages
                    if let error = errorMessage {
                        Label(error, systemImage: "exclamationmark.circle")
                            .font(.caption).foregroundStyle(.red)
                            .multilineTextAlignment(.center).padding(.horizontal)
                    }
                    if let success = successMessage {
                        Label(success, systemImage: "checkmark.circle.fill")
                            .font(.subheadline.weight(.semibold)).foregroundStyle(.green)
                    }

                    // CTA
                    VStack(spacing: 10) {
                        if !storeKit.hasLifetime {
                        Button { Task { await purchaseSelected() } } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(selectedProductId == nil ? Color.gray.opacity(0.4) : Color.orange)
                                if isLoading {
                                    ProgressView().tint(.white)
                                } else {
                                    Text(selectionIsOneTime ? "Buy Lifetime Access" : "Subscribe Now")
                                        .font(.headline).foregroundStyle(.white)
                                }
                            }
                            .frame(maxWidth: .infinity).frame(height: 54)
                        }
                        .disabled(isLoading || selectedProductId == nil)
                        .padding(.horizontal)
                        }

                        Button("Restore Purchases") { Task { await restorePurchases() } }
                            .font(.subheadline).foregroundStyle(.secondary)
                    }

                    VStack(spacing: 6) {
                        Text(selectionIsOneTime
                             ? "Lifetime access is a one-time purchase charged to your Apple ID at confirmation. It does not renew and there is nothing to cancel."
                             : "Subscriptions renew automatically until canceled. Cancel anytime in the App Store at least 24 hours before the end of the current period. Payment is charged to your Apple ID account at confirmation of purchase.")
                            .font(.caption2).foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)

                        HStack(spacing: 4) {
                            Link("Terms of Use",
                                 destination: URL(string: "https://www.dadbytes.app/terms")!)
                            Text("and").foregroundStyle(.tertiary)
                            Link("Privacy Policy",
                                 destination: URL(string: "https://www.dadbytes.app/data-privacy")!)
                        }
                        .font(.caption2)
                        .tint(.orange)
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 24)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task {
            if storeKit.products.isEmpty { await storeKit.loadProducts() }
            selectedProductId = storeKit.products.first?.id
        }
    }

    private func purchaseSelected() async {
        guard let id = selectedProductId,
              let product = storeKit.products.first(where: { $0.id == id }) else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            guard let result = try await storeKit.purchase(product) else { return }
            let tier = try await APIService.shared.verifyAppleIAP(
                signedTransaction: result.jws,
                productId: id
            )
            authService.updateTier(tier)
            successMessage = tier == .lifetime
                ? "Lifetime access unlocked — enjoy!"
                : "You now have \(tier.displayName) access!"
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            dismiss()
        } catch let error as AppError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "Purchase failed: \(error.localizedDescription)"
        }
    }

    private func restorePurchases() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await storeKit.restorePurchases()
            guard let entitlement = await storeKit.currentEntitlementJWS() else {
                successMessage = "No active purchases found."
                return
            }
            let tier = try await APIService.shared.verifyAppleIAP(
                signedTransaction: entitlement.jws,
                productId: entitlement.productId
            )
            authService.updateTier(tier)
            successMessage = "Purchases restored!"
        } catch let error as AppError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "Restore failed: \(error.localizedDescription)"
        }
    }
}

private struct FeatureRow: View {
    let icon: String
    let text: String
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(.orange).frame(width: 24)
            Text(text).font(.subheadline)
        }
    }
}

private struct ProductCard: View {
    let product: Product
    let isSelected: Bool
    let onSelect: () -> Void
    private var isYearly: Bool { product.id.contains("yearly") }
    private var isOneTime: Bool { product.type == .nonConsumable }

    private var periodLabel: String {
        if isOneTime { return "one time" }
        return isYearly ? "/ year" : "/ month"
    }

    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(product.displayName).font(.headline)
                        if isYearly {
                            Text("SAVE 17%").font(.caption2.bold())
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Color.green.opacity(0.15)).foregroundStyle(.green)
                                .clipShape(Capsule())
                        }
                        if isOneTime {
                            Text("BEST VALUE").font(.caption2.bold())
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Color.orange.opacity(0.15)).foregroundStyle(.orange)
                                .clipShape(Capsule())
                        }
                    }
                    Text(product.description).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(product.displayPrice).font(.headline)
                    Text(periodLabel).font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(isSelected ? Color.orange : Color(.systemGray4), lineWidth: isSelected ? 2 : 1)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(isSelected ? Color.orange.opacity(0.06) : Color(.systemBackground))
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
