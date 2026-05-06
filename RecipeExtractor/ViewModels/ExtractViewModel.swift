import Foundation

@MainActor
final class ExtractViewModel: ObservableObject {
    @Published var urlText = ""
    @Published var extractedRecipe: Recipe?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showPaywall = false
    @Published var showSignIn = false

    private let api = APIService.shared

    func extract() async {
        let url = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !url.isEmpty else {
            errorMessage = "Please enter a recipe URL."
            return
        }
        isLoading = true
        errorMessage = nil
        extractedRecipe = nil
        defer { isLoading = false }

        do {
            extractedRecipe = try await api.extractRecipe(url: url)
        } catch AppError.requiresSignup(let msg) {
            showSignIn = true
            errorMessage = msg
        } catch AppError.requiresUpgrade(let msg) {
            showPaywall = true
            errorMessage = msg
        } catch AppError.unauthorized {
            showSignIn = true
            errorMessage = "Sign in to extract recipes."
        } catch let error as AppError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func reset() {
        extractedRecipe = nil
        urlText = ""
        errorMessage = nil
        showPaywall = false
        showSignIn = false
    }
}
