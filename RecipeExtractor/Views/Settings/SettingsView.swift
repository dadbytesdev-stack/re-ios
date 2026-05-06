import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var storeKit: StoreKitService
    @State private var usage: UsageResponse?
    @State private var showPaywall = false
    @State private var showSignOutConfirm = false
    @State private var isRestoring = false
    @State private var restoreMessage: String?

    var body: some View {
        NavigationStack {
            List {
                // Account section
                if let user = authService.currentUser {
                    Section("Account") {
                        HStack(spacing: 14) {
                            Image(systemName: "person.crop.circle.fill")
                                .font(.system(size: 44))
                                .foregroundStyle(.orange)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(user.name ?? user.email)
                                    .font(.headline)
                                if user.name != nil {
                                    Text(user.email)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    // Usage section
                    Section("Usage") {
                        if let usage {
                            UsageBarView(used: usage.used, limit: max(usage.limit, 1), tier: usage.tier)
                                .padding(.vertical, 4)
                        } else {
                            ProgressView().frame(maxWidth: .infinity)
                        }
                        if user.tier == .free || user.tier == .premium {
                            Button {
                                showPaywall = true
                            } label: {
                                Label(
                                    user.tier == .free ? "Upgrade to Premium" : "Upgrade to Pro",
                                    systemImage: "crown.fill"
                                )
                                .foregroundStyle(.orange)
                            }
                        }
                    }
                }

                // Subscription section
                Section("Subscription") {
                    if let tier = authService.currentUser?.tier {
                        LabeledContent("Current Plan", value: tier.displayName)
                    }
                    Button {
                        Task { await restore() }
                    } label: {
                        HStack {
                            Text("Restore Purchases")
                            if isRestoring { Spacer(); ProgressView() }
                        }
                    }
                    .disabled(isRestoring)
                    if let msg = restoreMessage {
                        Text(msg).font(.caption).foregroundStyle(.secondary)
                    }
                }

                // App section
                Section("App") {
                    LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                    Link("Privacy Policy", destination: URL(string: "https://re-flax.vercel.app/privacy")!)
                    Link("Terms of Service", destination: URL(string: "https://re-flax.vercel.app/terms")!)
                }

                // Sign out
                Section {
                    Button(role: .destructive) {
                        showSignOutConfirm = true
                    } label: {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
            .navigationTitle("Account")
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
            .confirmationDialog("Sign Out", isPresented: $showSignOutConfirm, titleVisibility: .visible) {
                Button("Sign Out", role: .destructive) { authService.logout() }
            } message: {
                Text("You'll need to sign in again to access your recipes.")
            }
            .task { await loadUsage() }
            .refreshable { await loadUsage() }
        }
    }

    private func loadUsage() async {
        usage = try? await APIService.shared.getUsage()
    }

    private func restore() async {
        isRestoring = true
        restoreMessage = nil
        defer { isRestoring = false }
        do {
            try await storeKit.restorePurchases()
            guard !storeKit.purchasedProductIds.isEmpty,
                  let productId = storeKit.purchasedProductIds.first,
                  let receiptData = storeKit.getReceiptData() else {
                restoreMessage = "No active purchases found."
                return
            }
            let tier = try await APIService.shared.verifyAppleIAP(receiptData: receiptData, productId: productId)
            authService.updateTier(tier)
            restoreMessage = "Restored \(tier.displayName) successfully!"
            await loadUsage()
        } catch {
            restoreMessage = "Restore failed. Please try again."
        }
    }
}
