import SwiftUI

/// The nudge guests see wherever an account is needed. Deliberately soft: it
/// explains what signing in buys them rather than blocking the screen.
struct SignInPromptView: View {
    var icon: String = "bookmark.circle.fill"
    var title: String = "Make sure you sign in to save!"
    var message: String = "Don't lose your recipes!"
    var detail: String?
    var buttonTitle: String = "Sign In / Create Account"
    let onSignIn: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 52))
                .foregroundStyle(.orange)

            VStack(spacing: 6) {
                Text(title)
                    .font(.title3.bold())
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(.headline)
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
                if let detail {
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 2)
                }
            }
            .padding(.horizontal, 24)

            Button(action: onSignIn) {
                Text(buttonTitle)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.orange)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 32)
        }
        .padding(.vertical, 24)
    }
}

/// Compact version of the same nudge, shown under a guest's extracted recipe
/// where a full-screen prompt would push the result off the page.
struct SignInBanner: View {
    let onSignIn: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "bookmark.fill")
                    .foregroundStyle(.orange)
                    .font(.title3)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Make sure you sign in to save!")
                        .font(.subheadline.weight(.semibold))
                    Text("Don't lose your recipes!")
                        .font(.subheadline)
                        .foregroundStyle(.orange)
                    Text("Creating a free account gets you \(GuestSession.freeTierExtractions) more extractions every month.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }

            Button(action: onSignIn) {
                Text("Sign In / Create Account")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(.orange)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(14)
        .background(Color.orange.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.orange.opacity(0.35), lineWidth: 1)
        )
    }
}
