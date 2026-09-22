import SwiftUI

@main
struct RecipeExtractorApp: App {
    @StateObject private var authService = AuthService()
    @StateObject private var storeKit = StoreKitService()
    @StateObject private var guest = GuestSession()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authService)
                .environmentObject(storeKit)
                .environmentObject(guest)
                .task { await storeKit.loadProducts() }
        }
    }
}
