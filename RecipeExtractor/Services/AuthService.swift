import Foundation

@MainActor
final class AuthService: ObservableObject {
    @Published var currentUser: User?
    @Published var isAuthenticated = false
    @Published var isLoading = false

    private let keychain = KeychainService.shared
    private let api = APIService.shared

    init() { restoreSession() }

    private func restoreSession() {
        guard keychain.getToken() != nil,
              let data = UserDefaults.standard.data(forKey: "currentUser"),
              let user = try? JSONDecoder().decode(User.self, from: data) else { return }
        currentUser = user
        isAuthenticated = true
    }

    private func persistUser(_ user: User) {
        currentUser = user
        if let data = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(data, forKey: "currentUser")
        }
        isAuthenticated = true
    }

    func login(email: String, password: String) async throws {
        isLoading = true
        defer { isLoading = false }
        let response = try await api.login(email: email, password: password)
        keychain.saveToken(response.token)
        persistUser(response.user)
    }

    func register(name: String, email: String, password: String) async throws {
        isLoading = true
        defer { isLoading = false }
        try await api.register(name: name, email: email, password: password)
        try await login(email: email, password: password)
    }

    func logout() {
        keychain.deleteToken()
        UserDefaults.standard.removeObject(forKey: "currentUser")
        currentUser = nil
        isAuthenticated = false
    }

    func refreshUser() async {
        guard let usage = try? await api.getUsage() else { return }
        currentUser?.tier = usage.tier
        if let user = currentUser, let data = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(data, forKey: "currentUser")
        }
    }

    func updateTier(_ tier: SubscriptionTier) {
        currentUser?.tier = tier
        if let user = currentUser, let data = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(data, forKey: "currentUser")
        }
    }
}
