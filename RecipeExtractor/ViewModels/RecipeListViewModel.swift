import Foundation

@MainActor
final class RecipeListViewModel: ObservableObject {
    @Published var recipes: [RecipeListItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var currentPage = 1
    @Published var totalPages = 1
    @Published var hasMore = false

    var listType: String = "saved"
    private let api = APIService.shared

    func load() async {
        isLoading = true
        errorMessage = nil
        currentPage = 1
        defer { isLoading = false }
        do {
            let response = try await api.getRecipes(type: listType, page: 1)
            recipes = response.recipes
            totalPages = response.pagination.pages
            hasMore = response.pagination.pages > 1
        } catch let error as AppError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadMore() async {
        guard hasMore, !isLoading else { return }
        let nextPage = currentPage + 1
        guard nextPage <= totalPages else { return }
        do {
            let response = try await api.getRecipes(type: listType, page: nextPage)
            recipes.append(contentsOf: response.recipes)
            currentPage = nextPage
            hasMore = nextPage < response.pagination.pages
        } catch {}
    }

    func delete(id: String) async {
        do {
            try await api.deleteRecipe(id: id)
            recipes.removeAll { $0.id == id }
        } catch {
            errorMessage = "Failed to delete recipe."
        }
    }
}
