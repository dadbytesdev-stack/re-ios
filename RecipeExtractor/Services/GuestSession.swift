import Foundation

/// Tracks the free extraction someone gets before we ask them to sign in, and
/// whether they chose to look around without an account.
///
/// The server caps guests too (1 per IP), but that cap lives in an in-memory
/// map inside a serverless function — it resets on cold start and is not
/// shared between instances, so it cannot be relied on to fire at the right
/// moment. Counting locally means the sign-in prompt appears when *this*
/// person has used *their* trial, whichever server instance answered.
///
/// Neither counter is a security boundary: the local one is reset by deleting
/// the app. That is an acceptable trade for a single free extraction, and the
/// monthly limits that matter are enforced server-side against a real account.
@MainActor
final class GuestSession: ObservableObject {
    /// Extractions allowed before an account is required.
    static let trialExtractions = 1

    /// Extractions a signed-in free account gets each month. Shown in the
    /// prompts that ask guests to sign up, so it must match
    /// `SubscriptionTier.free.monthlyLimit`.
    static var freeTierExtractions: Int { SubscriptionTier.free.monthlyLimit ?? 0 }

    @Published private(set) var extractionsUsed: Int {
        didSet { defaults.set(extractionsUsed, forKey: Keys.used) }
    }

    /// True when someone tapped "try it first" rather than signing in. Persisted
    /// so backgrounding the app does not throw them back to the login screen
    /// mid-trial.
    @Published var isBrowsing: Bool {
        didSet { defaults.set(isBrowsing, forKey: Keys.browsing) }
    }

    private enum Keys {
        static let used = "guest.extractionsUsed"
        static let browsing = "guest.isBrowsing"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.extractionsUsed = defaults.integer(forKey: Keys.used)
        self.isBrowsing = defaults.bool(forKey: Keys.browsing)
    }

    var hasTrialRemaining: Bool { extractionsUsed < Self.trialExtractions }

    func recordExtraction() { extractionsUsed += 1 }

    /// The trial is over once there is an account to extract against.
    func end() {
        isBrowsing = false
        extractionsUsed = 0
    }
}
