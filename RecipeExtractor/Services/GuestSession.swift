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

    /// True once the app has opened straight into the trial on a first launch.
    ///
    /// Persisted and never cleared, not even by `end()`. That is the point: the
    /// auto-start must happen exactly once per install, so that signing out
    /// returns to the login screen instead of silently handing out another
    /// no-account extraction on every launch.
    @Published private(set) var hasAutoStarted: Bool {
        didSet { defaults.set(hasAutoStarted, forKey: Keys.autoStarted) }
    }

    private enum Keys {
        static let used = "guest.extractionsUsed"
        static let browsing = "guest.isBrowsing"
        static let autoStarted = "guest.hasAutoStarted"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.extractionsUsed = defaults.integer(forKey: Keys.used)
        self.isBrowsing = defaults.bool(forKey: Keys.browsing)
        self.hasAutoStarted = defaults.bool(forKey: Keys.autoStarted)
    }

    var hasTrialRemaining: Bool { extractionsUsed < Self.trialExtractions }

    /// Opens the app in guest mode on a cold first launch, so the first thing a
    /// new install shows is the URL box rather than a sign-in form. Idempotent,
    /// and only ever fires once per install.
    func startTrialOnFirstLaunch() {
        guard !hasAutoStarted, hasTrialRemaining else { return }
        hasAutoStarted = true
        isBrowsing = true
    }

    func recordExtraction() { extractionsUsed += 1 }

    /// The trial is over once there is an account to extract against.
    ///
    /// `hasAutoStarted` deliberately survives this, so a later sign-out lands
    /// on the login screen rather than back in a guest trial.
    func end() {
        isBrowsing = false
        extractionsUsed = 0
    }
}
