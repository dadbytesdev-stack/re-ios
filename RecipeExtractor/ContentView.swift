import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var guest: GuestSession

    var body: some View {
        Group {
            // Guests get the full app shell so they can try an extraction
            // before committing to an account; the tabs that need one prompt
            // for sign-in rather than disappearing.
            if authService.isAuthenticated || guest.isBrowsing {
                MainTabView()
            } else {
                LoginView(showsGuestEntry: true)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: authService.isAuthenticated)
        .animation(.easeInOut(duration: 0.25), value: guest.isBrowsing)
        .onChange(of: authService.isAuthenticated) { _, signedIn in
            // Signing in (or creating an account) retires the trial.
            if signedIn { guest.end() }
        }
    }
}
