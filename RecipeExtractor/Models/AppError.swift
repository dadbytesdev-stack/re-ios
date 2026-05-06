import Foundation

enum AppError: LocalizedError {
    case unauthorized
    case networkError(String)
    case serverError(String)
    case extractionLimitReached(String)
    case requiresUpgrade(String)
    case requiresSignup(String)
    case unknown

    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Please sign in to continue."
        case .networkError(let msg):
            return "Network error: \(msg)"
        case .serverError(let msg):
            return msg
        case .extractionLimitReached(let msg):
            return msg
        case .requiresUpgrade(let msg):
            return msg
        case .requiresSignup(let msg):
            return msg
        case .unknown:
            return "An unexpected error occurred."
        }
    }

    var requiresPaywall: Bool {
        if case .requiresUpgrade = self { return true }
        return false
    }

    var requiresAuth: Bool {
        if case .requiresSignup = self { return true }
        if case .unauthorized = self { return true }
        return false
    }
}
