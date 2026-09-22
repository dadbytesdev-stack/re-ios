import SwiftUI

struct LoginView: View {
    /// Shown as the app's first screen (true) or as a sheet from inside the
    /// app (false). Only the first screen offers the no-account trial —
    /// once someone has spent it, the sheet should not dangle it again.
    var showsGuestEntry: Bool = false

    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var guest: GuestSession
    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var showRegister = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    // Logo
                    VStack(spacing: 12) {
                        Image(systemName: "fork.knife.circle.fill")
                            .font(.system(size: 72))
                            .foregroundStyle(.orange)
                        Text("Recipe Extractor")
                            .font(.largeTitle.bold())
                        Text("Save any recipe from the web")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 48)

                    // Form
                    VStack(spacing: 14) {
                        TextField("Email address", text: $email)
                            .textFieldStyle(.roundedBorder)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)
                            .autocorrectionDisabled()

                        SecureField("Password", text: $password)
                            .textFieldStyle(.roundedBorder)

                        if let error = errorMessage {
                            Label(error, systemImage: "exclamationmark.circle")
                                .font(.caption)
                                .foregroundStyle(.red)
                                .multilineTextAlignment(.center)
                        }

                        Button {
                            Task { await login() }
                        } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(.orange)
                                if isLoading {
                                    ProgressView().tint(.white)
                                } else {
                                    Text("Sign In")
                                        .font(.headline)
                                        .foregroundStyle(.white)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                        }
                        .disabled(isLoading || email.isEmpty || password.isEmpty)
                    }
                    .padding(.horizontal, 24)

                    // Sign up link
                    Button {
                        showRegister = true
                    } label: {
                        Text("Don't have an account? ")
                            .foregroundStyle(.secondary)
                        + Text("Sign up free")
                            .foregroundStyle(.orange)
                            .fontWeight(.semibold)
                    }
                    .font(.subheadline)

                    // No-account trial. Hidden once it has been used, so the
                    // button never promises something the next tap refuses.
                    if showsGuestEntry && guest.hasTrialRemaining {
                        VStack(spacing: 8) {
                            Divider().padding(.horizontal, 48)
                            Button {
                                guest.isBrowsing = true
                            } label: {
                                Text("Try it free — no account needed")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.orange)
                            }
                            Text("Extract \(GuestSession.trialExtractions) recipe now, then sign in for \(GuestSession.freeTierExtractions) free extractions every month.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 4)
                    }
                }
                .padding(.bottom, 40)
            }
            .navigationDestination(isPresented: $showRegister) {
                RegisterView()
            }
        }
    }

    private func login() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await authService.login(email: email, password: password)
        } catch let error as AppError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
