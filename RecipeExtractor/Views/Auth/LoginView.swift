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

    /// True when the no-account trial is actually on offer on this screen.
    /// Drives the visual hierarchy: whichever action is the better one for a
    /// first-time visitor is the filled button, and there is only ever one.
    private var offersGuestEntry: Bool {
        showsGuestEntry && guest.hasTrialRemaining
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    // Logo
                    VStack(spacing: 12) {
                        Image(systemName: "fork.knife.circle.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(.orange)
                        Text("Recipe Extractor")
                            .font(.largeTitle.bold())
                        Text("Save any recipe from the web")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 40)

                    // No-account trial, first and primary. Hidden once it has
                    // been used, so the button never promises something the
                    // next tap refuses.
                    if offersGuestEntry {
                        VStack(spacing: 10) {
                            Button {
                                guest.isBrowsing = true
                            } label: {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(.orange)
                                    Text("Extract a recipe now")
                                        .font(.headline)
                                        .foregroundStyle(.white)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                            }

                            Text("Free, no account needed. Sign up afterwards to keep it and get \(GuestSession.freeTierExtractions) extractions every month.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal, 24)
                    }

                    // Existing account. Sits below the offer and is styled as
                    // the secondary action whenever the trial is available.
                    VStack(spacing: 14) {
                        if offersGuestEntry {
                            Text("Already have an account?")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }

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
                                    .fill(offersGuestEntry ? Color.orange.opacity(0.12) : Color.orange)
                                if isLoading {
                                    ProgressView().tint(offersGuestEntry ? .orange : .white)
                                } else {
                                    Text("Sign In")
                                        .font(.headline)
                                        .foregroundStyle(offersGuestEntry ? .orange : .white)
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
