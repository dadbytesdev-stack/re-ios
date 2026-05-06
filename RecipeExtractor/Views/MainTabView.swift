import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var authService: AuthService

    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(0)

            RecipeListView()
                .tabItem { Label("Saved", systemImage: "bookmark.fill") }
                .tag(1)

            SettingsView()
                .tabItem { Label("Account", systemImage: "person.fill") }
                .tag(2)
        }
        .tint(.orange)
    }
}
