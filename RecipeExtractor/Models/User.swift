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
    case lifetime = "LIFETIME"

    /// Tolerate a tier the server knows about but this build does not, rather
    /// than failing to decode the whole user and logging someone out.
    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = SubscriptionTier(rawValue: raw.uppercased()) ?? .free
    }

    var displayName: String {
        switch self {
        case .free: return "Free"
        case .premium: return "Premium"
        case .pro: return "Pro"
        case .lifetime: return "Lifetime"
        }
    }

    /// Extractions allowed per month; nil means unlimited.
    ///
    /// These values mirror TIER_LIMITS in the backend, which is what actually
    /// enforces them — this copy only drives what the UI says. If the two ever
    /// disagree, the server wins and the user sees a limit they were not
    /// warned about, so keep them in step.
    var monthlyLimit: Int? {
        switch self {
        case .free: return 10
        case .premium: return 20
        case .pro, .lifetime: return nil
        }
    }

    var isUnlimited: Bool { monthlyLimit == nil }

    /// Every signed-in tier can save recipes. Saving is the hook that gets
    /// people to create an account, so it is no longer held back for paid
    /// plans — guests are the only ones who cannot save.
    var canSaveRecipes: Bool { true }
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
