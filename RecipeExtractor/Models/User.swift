import Foundation

struct User: Codable {
    let id: String
    let email: String
    let name: String?
    var tier: SubscriptionTier
}

enum SubscriptionTier: String, Codable, CaseIterable {
    case free = "FREE"
    case premium = "PREMIUM"
    case pro = "PRO"

    var displayName: String {
        switch self {
        case .free: return "Free"
        case .premium: return "Premium"
        case .pro: return "Pro"
        }
    }

    var monthlyLimit: Int? {
        switch self {
        case .free: return 1
        case .premium: return 10
        case .pro: return nil
        }
    }

    var canSaveRecipes: Bool { self != .free }
}

struct LoginResponse: Codable {
    let token: String
    let user: User
}

struct UsageResponse: Codable {
    let allowed: Bool
    let used: Int
    let limit: Int
    let tier: SubscriptionTier
}
