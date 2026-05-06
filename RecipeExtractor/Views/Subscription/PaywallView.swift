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
                        Text("Extract and save as many recipes as you like")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 24)

                    // Feature highlights
                    VStack(alignment: .leading, spacing: 12) {
                        FeatureRow(icon: "wand.and.stars", text: "Unlimited recipe extractions")
                        FeatureRow(icon: "bookmark.fill", text: "Save your recipe library")
                        FeatureRow(icon: "arrow.clockwise", text: "Access past extractions")
                        FeatureRow(icon: "star.fill", text: "Priority support")
                    }
                    .padding(.horizontal, 32)

                    // Products
                    if storeKit.products.isEmpty {
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
                        Button { Task { await purchaseSelected() } } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(selectedProductId == nil ? Color.gray.opacity(0.4) : Color.orange)
                                if isLoading {
                                    ProgressView().tint(.white)
                                } else {
                                    Text("Subscribe Now").font(.headline).foregroundStyle(.white)
                                }
                            }
                            .frame(maxWidth: .infinity).frame(height: 54)
                        }
                        .disabled(isLoading || selectedProductId == nil)
                        .padding(.horizontal)

                        Button("Restore Purchases") { Task { await restorePurchases() } }
                            .font(.subheadline).foregroundStyle(.secondary)
                    }

                    Text("Subscriptions renew automatically. Cancel anytime in the App Store.")
                        .font(.caption2).foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center).padding(.horizontal, 32).padding(.bottom, 24)
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
            guard let _ = try await storeKit.purchase(product) else { return }
            guard let receiptData = storeKit.getReceiptData() else {
                errorMessage = "Could not read receipt. Try restoring purchases."
                return
            }
            let tier = try await APIService.shared.verifyAppleIAP(receiptData: receiptData, productId: id)
            authService.updateTier(tier)
            successMessage = "You now have \(tier.displayName) access!"
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
            guard !storeKit.purchasedProductIds.isEmpty,
                  let productId = storeKit.purchasedProductIds.first,
                  let receiptData = storeKit.getReceiptData() else {
                successMessage = "No active purchases found."
                return
            }
            let tier = try await APIService.shared.verifyAppleIAP(receiptData: receiptData, productId: productId)
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
                    }
                    Text(product.description).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(product.displayPrice).font(.headline)
                    Text(isYearly ? "/ year" : "/ month").font(.caption).foregroundStyle(.secondary)
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
