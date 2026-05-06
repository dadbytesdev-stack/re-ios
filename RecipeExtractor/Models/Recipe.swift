import Foundation

struct Recipe: Codable, Identifiable {
    let id: String?
    let title: String
    let sourceUrl: String
    let image: String?
    let prepTime: String?
    let cookTime: String?
    let servings: String?
    let ingredients: [String]
    let instructions: [String]
    let isSaved: Bool?
    let createdAt: String?
}

struct RecipeListItem: Codable, Identifiable {
    let id: String
    let title: String
    let sourceUrl: String
    let image: String?
    let prepTime: String?
    let cookTime: String?
    let servings: String?
    let isSaved: Bool
    let createdAt: String
}

struct RecipeListResponse: Codable {
    let recipes: [RecipeListItem]
    let pagination: Pagination
}

struct Pagination: Codable {
    let page: Int
    let limit: Int
    let total: Int
    let pages: Int
}

struct ExtractResponse: Codable {
    let recipe: Recipe
    let isGuest: Bool?
}
