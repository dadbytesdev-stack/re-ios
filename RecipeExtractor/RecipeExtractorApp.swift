import SwiftUI

@main
struct RecipeExtractorApp: App {
    @StateObject private var authService = AuthService()
    @StateObject private var storeKit = StoreKitService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authService)
                .environmentObject(storeKit)
                .task { await storeKit.loadProducts() }
        }
    }
}
