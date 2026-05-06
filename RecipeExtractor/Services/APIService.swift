import Foundation

final class APIService {
    static let shared = APIService()
    private init() {}

    // Switch to "http://localhost:3000" for local development
    let baseURL = "https://re-flax.vercel.app"

    private var authToken: String? { KeychainService.shared.getToken() }

    private func makeRequest(
        _ path: String,
        method: String = "GET",
        body: [String: Any]? = nil
    ) async throws -> Data {
        guard let url = URL(string: baseURL + path) else {
            throw AppError.networkError("Invalid URL")
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AppError.networkError("Invalid response")
        }

        switch http.statusCode {
        case 200..<300:
            return data
        case 401:
            throw AppError.unauthorized
        case 403:
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let msg = json["message"] as? String ?? json["error"] as? String ?? "Access denied"
                if json["requiresSignup"] as? Bool == true {
                    throw AppError.requiresSignup(msg)
                }
                throw AppError.requiresUpgrade(msg)
            }
            throw AppError.requiresUpgrade("Upgrade required")
        default:
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = json["error"] as? String {
                throw AppError.serverError(error)
            }
            throw AppError.serverError("Request failed (\(http.statusCode))")
        }
    }

    // MARK: - Auth

    func login(email: String, password: String) async throws -> LoginResponse {
        let data = try await makeRequest("/api/auth/mobile/signin", method: "POST",
                                        body: ["email": email, "password": password])
        return try JSONDecoder().decode(LoginResponse.self, from: data)
    }

    func register(name: String, email: String, password: String) async throws {
        _ = try await makeRequest("/api/auth/register", method: "POST",
                                  body: ["name": name, "email": email, "password": password])
    }

    // MARK: - Usage

    func getUsage() async throws -> UsageResponse {
        let data = try await makeRequest("/api/user/usage")
        return try JSONDecoder().decode(UsageResponse.self, from: data)
    }

    // MARK: - Extract

    func extractRecipe(url: String) async throws -> Recipe {
        let data = try await makeRequest("/api/extract", method: "POST", body: ["url": url])
        return try JSONDecoder().decode(ExtractResponse.self, from: data).recipe
    }

    // MARK: - Recipes

    func getRecipes(type: String = "saved", page: Int = 1) async throws -> RecipeListResponse {
        let data = try await makeRequest("/api/recipes?type=\(type)&page=\(page)&limit=10")
        return try JSONDecoder().decode(RecipeListResponse.self, from: data)
    }

    func getRecipe(id: String) async throws -> Recipe {
        let data = try await makeRequest("/api/recipes/\(id)")
        struct Wrapper: Codable { let recipe: Recipe }
        return try JSONDecoder().decode(Wrapper.self, from: data).recipe
    }

    func deleteRecipe(id: String) async throws {
        _ = try await makeRequest("/api/recipes/\(id)", method: "DELETE")
    }

    func toggleSaveRecipe(id: String) async throws -> Bool {
        let data = try await makeRequest("/api/recipes/\(id)", method: "PATCH")
        struct Wrapper: Codable { let isSaved: Bool }
        return try JSONDecoder().decode(Wrapper.self, from: data).isSaved
    }

    // MARK: - Apple IAP

    func verifyAppleIAP(receiptData: String, productId: String) async throws -> SubscriptionTier {
        let data = try await makeRequest("/api/apple/verify-iap", method: "POST",
                                        body: ["receiptData": receiptData, "productId": productId])
        struct Wrapper: Codable { let tier: SubscriptionTier }
        return try JSONDecoder().decode(Wrapper.self, from: data).tier
    }
}
