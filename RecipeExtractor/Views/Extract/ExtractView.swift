import SwiftUI

struct ExtractView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var storeKit: StoreKitService
    @StateObject private var viewModel = ExtractViewModel()
    @State private var showPaywall = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // URL input bar
                VStack(spacing: 12) {
                    HStack(spacing: 10) {
                        Image(systemName: "link")
                            .foregroundStyle(.secondary)
                        TextField("Paste a recipe URL...", text: $viewModel.urlText)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)
                            .submitLabel(.go)
                            .onSubmit { Task { await viewModel.extract() } }
                        if !viewModel.urlText.isEmpty {
                            Button { viewModel.urlText = "" } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(12)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    Button {
                        Task { await viewModel.extract() }
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(viewModel.urlText.isEmpty ? Color.gray.opacity(0.4) : Color.orange)
                            if viewModel.isLoading {
                                HStack(spacing: 8) {
                                    ProgressView().tint(.white)
                                    Text("Extracting...").foregroundStyle(.white).font(.headline)
                                }
                            } else {
                                Label("Extract Recipe", systemImage: "wand.and.stars")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                    }
                    .disabled(viewModel.isLoading || viewModel.urlText.isEmpty)
                }
                .padding(.horizontal)
                .padding(.top, 16)
                .padding(.bottom, 12)
                .background(Color(.systemBackground))

                Divider()

                // Result area
                if let recipe = viewModel.extractedRecipe {
                    RecipeResultView(
                        recipe: recipe,
                        onSave: authService.currentUser?.tier.canSaveRecipes == true ? {
                            // Already saved server-side; show confirmation
                            viewModel.reset()
                        } : nil,
                        onExtractNew: { viewModel.reset() }
                    )
                } else if viewModel.isLoading {
                    Spacer()
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Extracting recipe…")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                } else if let error = viewModel.errorMessage {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 44))
                            .foregroundStyle(.orange)
                        Text(error)
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 40)
                    }
                    Spacer()
                } else {
                    EmptyExtractState()
                }
            }
            .navigationTitle("Extract")
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
            .onChange(of: viewModel.showPaywall) { _, show in
                if show { showPaywall = true; viewModel.showPaywall = false }
            }
        }
    }
}

private struct EmptyExtractState: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "fork.knife.circle")
                .font(.system(size: 64))
                .foregroundStyle(Color.orange.opacity(0.4))
            Text("Paste any recipe URL")
                .font(.title3.weight(.semibold))
            Text("From AllRecipes, NYT Cooking, Food Network,\nor any site with a recipe.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
            Spacer()
        }
    }
}
