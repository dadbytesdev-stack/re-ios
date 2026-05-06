import SwiftUI

struct RecipeDetailView: View {
    let recipeId: String
    @State private var recipe: Recipe?
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let recipe {
                RecipeResultView(recipe: recipe)
            } else if let error = errorMessage {
                ContentUnavailableView("Error", systemImage: "exclamationmark.triangle",
                                       description: Text(error))
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadRecipe() }
    }

    private func loadRecipe() async {
        isLoading = true
        defer { isLoading = false }
        do {
            recipe = try await APIService.shared.getRecipe(id: recipeId)
        } catch let error as AppError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
