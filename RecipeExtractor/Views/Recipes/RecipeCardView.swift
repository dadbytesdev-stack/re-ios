import SwiftUI

struct RecipeCardView: View {
    let recipe: RecipeListItem

    var body: some View {
        HStack(spacing: 14) {
            // Thumbnail
            Group {
                if let imageURL = recipe.image, let url = URL(string: imageURL) {
                    AsyncImage(url: url) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Color(.systemGray5)
                    }
                } else {
                    Color(.systemGray5)
                        .overlay(Image(systemName: "fork.knife").foregroundStyle(.secondary))
                }
            }
            .frame(width: 72, height: 72)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(recipe.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)

                HStack(spacing: 10) {
                    if let prep = recipe.prepTime {
                        Label(prep, systemImage: "clock")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let cook = recipe.cookTime {
                        Label(cook, systemImage: "flame")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if let host = URL(string: recipe.sourceUrl)?.host {
                    Text(host.replacingOccurrences(of: "www.", with: ""))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()
        }
        .contentShape(Rectangle())
    }
}
