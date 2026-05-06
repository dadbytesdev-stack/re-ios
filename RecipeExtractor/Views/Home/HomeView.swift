import SwiftUI

struct HomeView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var extractVM = ExtractViewModel()
    @State private var usage: UsageResponse?
    @State private var showPaywall = false
    @State private var showSignIn = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Usage bar (authenticated only)
                    if authService.isAuthenticated, let usage {
                        VStack(spacing: 4) {
                            UsageBarView(used: usage.used, limit: max(usage.limit, 1), tier: usage.tier)
                            if !usage.allowed {
                                Button("Upgrade for more") { showPaywall = true }
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.orange)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                    }

                    // URL input card
                    VStack(spacing: 14) {
                        HStack(spacing: 10) {
                            Image(systemName: "link")
                                .foregroundStyle(.secondary)
                            TextField("Paste a recipe URL…", text: $extractVM.urlText)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .keyboardType(.URL)
                                .submitLabel(.go)
                                .onSubmit { Task { await extract() } }
                            if !extractVM.urlText.isEmpty {
                                Button { extractVM.urlText = "" } label: {
                                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(12)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                        Button { Task { await extract() } } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(extractVM.urlText.isEmpty ? Color.gray.opacity(0.35) : Color.orange)
                                if extractVM.isLoading {
                                    HStack(spacing: 8) {
                                        ProgressView().tint(.white)
                                        Text("Extracting…").foregroundStyle(.white).font(.headline)
                                    }
                                } else {
                                    Label("Extract Recipe", systemImage: "wand.and.stars")
                                        .font(.headline).foregroundStyle(.white)
                                }
                            }
                            .frame(maxWidth: .infinity).frame(height: 50)
                        }
                        .disabled(extractVM.isLoading || extractVM.urlText.isEmpty)
                    }
                    .padding(.horizontal)

                    // Error message
                    if let err = extractVM.errorMessage {
                        Label(err, systemImage: "exclamationmark.circle")
                            .font(.caption).foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    // Result
                    if let recipe = extractVM.extractedRecipe {
                        RecipeResultView(
                            recipe: recipe,
                            onExtractNew: { extractVM.reset() }
                        )
                        .padding(.horizontal)
                    } else if !authService.isAuthenticated {
                        GuestPromptView(onSignIn: { showSignIn = true })
                    } else if extractVM.extractedRecipe == nil && !extractVM.isLoading {
                        HowItWorksView()
                    }
                }
                .padding(.bottom, 40)
            }
            .navigationTitle("Recipe Extractor")
            .sheet(isPresented: $showPaywall) { PaywallView() }
            .sheet(isPresented: $showSignIn) { LoginView() }
            .task { await loadUsage() }
            .onChange(of: extractVM.showPaywall) { _, show in
                if show { showPaywall = true; extractVM.showPaywall = false }
            }
            .onChange(of: extractVM.showSignIn) { _, show in
                if show { showSignIn = true; extractVM.showSignIn = false }
            }
            .refreshable { await loadUsage() }
        }
    }

    private func extract() async {
        await extractVM.extract()
        if extractVM.extractedRecipe != nil { await loadUsage() }
    }

    private func loadUsage() async {
        guard authService.isAuthenticated else { return }
        usage = try? await APIService.shared.getUsage()
    }
}

private struct GuestPromptView: View {
    let onSignIn: () -> Void
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 52))
                .foregroundStyle(Color.orange.opacity(0.6))
            Text("Sign in to save recipes")
                .font(.title3.bold())
            Text("Create a free account to extract up to 1 recipe per month and save your history.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button(action: onSignIn) {
                Text("Sign In / Create Account")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.orange)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 40)
        }
        .padding(.top, 20)
    }
}

private struct HowItWorksView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("How it works")
                .font(.headline)
                .padding(.horizontal)
            ForEach(steps, id: \.title) { step in
                HStack(alignment: .top, spacing: 14) {
                    Text(step.number)
                        .font(.headline)
                        .frame(width: 32, height: 32)
                        .background(Color.orange.opacity(0.12))
                        .foregroundStyle(.orange)
                        .clipShape(Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text(step.title).font(.subheadline.weight(.semibold))
                        Text(step.detail).font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 8)
    }

    private let steps: [(number: String, title: String, detail: String)] = [
        ("1", "Paste any recipe URL", "From AllRecipes, NYT Cooking, Food Network, and more"),
        ("2", "We extract the recipe", "Ingredients and step-by-step instructions, clean and formatted"),
        ("3", "Save to your library", "Access your recipes anytime — no ads, no clutter")
    ]
}
