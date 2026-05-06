import SwiftUI

struct RecipeListView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var viewModel = RecipeListViewModel()
    @State private var selectedId: String?

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.recipes.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.recipes.isEmpty {
                    ContentUnavailableView(
                        "No Saved Recipes",
                        systemImage: "bookmark.slash",
                        description: Text("Recipes you save will appear here.")
                    )
                } else {
                    List {
                        ForEach(viewModel.recipes) { recipe in
                            NavigationLink(value: recipe.id) {
                                RecipeCardView(recipe: recipe)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    Task { await viewModel.delete(id: recipe.id) }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .onAppear {
                                if recipe.id == viewModel.recipes.last?.id {
                                    Task { await viewModel.loadMore() }
                                }
                            }
                        }
                        if viewModel.hasMore {
                            HStack { Spacer(); ProgressView(); Spacer() }
                                .listRowSeparator(.hidden)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Saved Recipes")
            .navigationDestination(for: String.self) { id in
                RecipeDetailView(recipeId: id)
            }
            .refreshable { await viewModel.load() }
            .task { await viewModel.load() }
        }
    }
}
