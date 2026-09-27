import SwiftUI
import StoreKit

/// Why the paywall is on screen. A sheet that opens because an extraction was
/// just refused is answering a question the user already has; one opened from
/// Settings has to raise the subject itself. The copy differs accordingly.
enum PaywallContext {
    /// Opened from Settings or another browsing entry point.
    case browse
    /// Opened because the monthly limit has just been hit.
    case quotaReached
}

struct PaywallView: View {
    /// Defaults to `.browse` so existing presentations compile unchanged.
    var context: PaywallContext = .browse

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

    /// True only once StoreKit has actually returned a one-time product. While
    /// Lifetime is in App Store review it will not load, and the sheet must not
    /// describe a plan that cannot be bought yet.
    private var offersLifetime: Bool {
        storeKit.products.contains { $0.type == .nonConsumable }
    }

    private var headerIcon: String {
        switch context {
        case .quotaReached: return "hourglass"
        case .browse: return "crown.fill"
        }
    }

    private var headline: String {
        switch context {
        case .quotaReached:
            if let limit = authService.currentUser?.tier.monthlyLimit {
                return "That's all \(limit) extractions this month"
            }
            return "You've used this month's extractions"
        case .browse:
            return "Keep every recipe you find"
        }
    }

    private var subhead: String {
        switch context {
        case .quotaReached:
            return "Upgrade and your next extraction works straight away. Everything you have already saved stays exactly where it is."
        case .browse:
            return "You're on \(authService.currentUser?.tier.displayName ?? "Free") — here's what more looks like."
        }
    }

    /// The price belongs on the button: it is the one thing someone needs to
    /// know before tapping, and hiding it behind "Subscribe Now" only delays
    /// the decision to the App Store sheet.
    private var ctaTitle: String {
        guard let product = selectedProduct else { return "Choose a plan" }
        if selectionIsOneTime { return "Unlock forever — \(product.displayPrice)" }
        let period = product.id.contains("yearly") ? "a year" : "a month"
        return "Continue — \(product.displayPrice) \(period)"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: headerIcon)
                            .font(.system(size: 48))
                            .foregroundStyle(.orange)
                        Text(headline)
                            .font(.title.bold())
                            .multilineTextAlignment(.center)
                        Text(subhead)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 24)

                    // Feature highlights
                    VStack(alignment: .leading, spacing: 12) {
                        FeatureRow(icon: "wand.and.stars",
                                   text: "\(SubscriptionTier.premium.monthlyLimit ?? 0) extractions a month")
                        if offersLifetime {
                            FeatureRow(icon: "checkmark.seal.fill",
                                       text: "Or pay once for unlimited, forever")
                        }
                        FeatureRow(icon: "bookmark.fill",
                                   text: "Every recipe saved to your library")
                        FeatureRow(icon: "text.alignleft",
                                   text: "Ingredients and steps only — no ads, no clutter")
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
                                    Text(ctaTitle)
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

    /// Deliberately not a percentage.
    ///
    /// This badge used to read "SAVE 17%", which is only true of $99.99/year
    /// against $9.99/month. Against a $14.99/year plan next to $2.99/month the
    /// real saving is 58%, so the constant was both wrong and wrong in our own
    /// favour — a discount claim has to be arithmetic on the two prices being
    /// compared, not a string. Until it is computed from the real pair, say
    /// nothing numeric.
    private var yearlyBadge: String { "BILLED YEARLY" }

    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(product.displayName).font(.headline)
                        if isYearly {
                            Text(yearlyBadge).font(.caption2.bold())
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
