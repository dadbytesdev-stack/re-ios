import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var authService: AuthService
    @State private var showSignIn = false

    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(0)

            Group {
                if authService.isAuthenticated {
                    RecipeListView()
                } else {
                    GuestTabPlaceholder(
                        title: "Saved Recipes",
                        icon: "bookmark.circle.fill",
                        detail: "Your saved recipes live here once you have an account.",
                        onSignIn: { showSignIn = true }
                    )
                }
            }
            .tabItem { Label("Saved", systemImage: "bookmark.fill") }
            .tag(1)

            Group {
                if authService.isAuthenticated {
                    SettingsView()
                } else {
                    GuestTabPlaceholder(
                        title: "Account",
                        icon: "person.crop.circle.fill",
                        detail: "Sign in to track your monthly extractions and manage your plan.",
                        onSignIn: { showSignIn = true }
                    )
                }
            }
            .tabItem { Label("Account", systemImage: "person.fill") }
            .tag(2)
        }
        .tint(.orange)
        .sheet(isPresented: $showSignIn) { LoginView() }
        // The root view no longer swaps on sign-in (guests already see the
        // tabs), so nothing else would take this sheet down.
        .onChange(of: authService.isAuthenticated) { _, signedIn in
            if signedIn { showSignIn = false }
        }
    }
}

private struct GuestTabPlaceholder: View {
    let title: String
    let icon: String
    let detail: String
    let onSignIn: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                SignInPromptView(
                    icon: icon,
                    detail: detail,
                    onSignIn: onSignIn
                )
                .padding(.top, 40)
            }
            .navigationTitle(title)
        }
    }
}
