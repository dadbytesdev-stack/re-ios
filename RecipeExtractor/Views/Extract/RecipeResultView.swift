import SwiftUI

struct RecipeResultView: View {
    let recipe: Recipe
    var onSave: (() -> Void)?
    var onExtractNew: (() -> Void)?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Hero image
                if let imageURL = recipe.image, let url = URL(string: imageURL) {
                    AsyncImage(url: url) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle().fill(Color(.systemGray5))
                            .overlay(Image(systemName: "fork.knife").font(.largeTitle).foregroundStyle(.secondary))
                    }
                    .frame(height: 240)
                    .clipped()
                }

                VStack(alignment: .leading, spacing: 20) {
                    // Title
                    Text(recipe.title)
                        .font(.title2.bold())

                    // Meta row
                    HStack(spacing: 20) {
                        if let prep = recipe.prepTime {
                            MetaChip(icon: "clock", label: "Prep", value: prep)
                        }
                        if let cook = recipe.cookTime {
                            MetaChip(icon: "flame", label: "Cook", value: cook)
                        }
                        if let servings = recipe.servings {
                            MetaChip(icon: "person.2", label: "Serves", value: servings)
                        }
                    }

                    Divider()

                    // Ingredients
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Ingredients")
                            .font(.headline)
                        ForEach(Array(recipe.ingredients.enumerated()), id: \.offset) { _, ingredient in
                            HStack(alignment: .top, spacing: 10) {
                                Circle()
                                    .fill(.orange)
                                    .frame(width: 6, height: 6)
                                    .padding(.top, 7)
                                Text(ingredient)
                                    .font(.subheadline)
                            }
                        }
                    }

                    Divider()

                    // Instructions
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Instructions")
                            .font(.headline)
                        ForEach(Array(recipe.instructions.enumerated()), id: \.offset) { index, step in
                            HStack(alignment: .top, spacing: 12) {
                                Text("\(index + 1)")
                                    .font(.caption.bold())
                                    .frame(width: 24, height: 24)
                                    .background(Color.orange.opacity(0.15))
                                    .foregroundStyle(.orange)
                                    .clipShape(Circle())
                                Text(step)
                                    .font(.subheadline)
                            }
                        }
                    }

                    // Source link
                    if let url = URL(string: recipe.sourceUrl) {
                        Link(destination: url) {
                            Label("View original recipe", systemImage: "safari")
                                .font(.subheadline)
                                .foregroundStyle(.orange)
                        }
                    }

                    // Actions
                    VStack(spacing: 10) {
                        if let onSave {
                            Button(action: onSave) {
                                Label("Save Recipe", systemImage: "bookmark.fill")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(.orange)
                                    .foregroundStyle(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                        if let onExtractNew {
                            Button(action: onExtractNew) {
                                Label("Extract Another", systemImage: "arrow.clockwise")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .foregroundStyle(.primary)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }
                }
                .padding(20)
            }
        }
    }
}

private struct MetaChip: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.orange)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.weight(.semibold))
        }
    }
}
