import Foundation

@MainActor
final class ExtractViewModel: ObservableObject {
    @Published var urlText = ""
    @Published var extractedRecipe: Recipe?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showPaywall = false
    @Published var showSignIn = false

    /// Set once a guest's extraction lands, so the view can nudge them to
    /// sign in while the recipe they just got is still in front of them.
    @Published var showSignInNudge = false

    @Published var isSaving = false
    @Published var saveMessage: String?

    private let api = APIService.shared

    /// - Parameter guest: the trial tracker when nobody is signed in, nil once
    ///   there is an account. Passing it in keeps the view model free of any
    ///   opinion about which of the two is in play.
    func extract(guest: GuestSession?) async {
        let url = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !url.isEmpty else {
            errorMessage = "Please enter a recipe URL."
            return
        }

        // A guest who has spent their trial is asked to sign in here rather
        // than after a round trip — the server would only refuse it, and the
        // wait would make the refusal feel like a failure.
        if let guest, !guest.hasTrialRemaining {
            showSignIn = true
            errorMessage = nil
            return
        }

        isLoading = true
        errorMessage = nil
        saveMessage = nil
        extractedRecipe = nil
        showSignInNudge = false
        defer { isLoading = false }

        do {
            let recipe = try await api.extractRecipe(url: url)
            extractedRecipe = recipe
            if let guest {
                guest.recordExtraction()
                showSignInNudge = true
            }
        } catch AppError.requiresSignup(let msg) {
            // The server's guest cap fired before ours did (different device,
            // shared IP). Treat it the same way: ask for an account.
            guest?.recordExtraction()
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

    /// Saves the recipe on screen to the signed-in user's library. Every tier
    /// can save, so the only thing that blocks this is not having an account —
    /// and a guest extraction has no server-side id to save against.
    func save() async {
        guard let id = extractedRecipe?.id else {
            saveMessage = "Sign in to save this recipe."
            showSignIn = true
            return
        }
        isSaving = true
        saveMessage = nil
        defer { isSaving = false }
        do {
            let isSaved = try await api.toggleSaveRecipe(id: id)
            saveMessage = isSaved ? "Saved to your recipes." : "Removed from your recipes."
        } catch let error as AppError {
            saveMessage = error.localizedDescription
        } catch {
            saveMessage = "Couldn't save this recipe."
        }
    }

    func reset() {
        extractedRecipe = nil
        urlText = ""
        errorMessage = nil
        saveMessage = nil
        showPaywall = false
        showSignIn = false
        showSignInNudge = false
    }
}
