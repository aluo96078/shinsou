import SwiftUI
import AuthenticationServices
import MihonDomain
import MihonI18n

// MARK: - TrackerLoginSheet

/// Presented when a user taps a tracker they haven't authenticated with yet.
/// Launches ASWebAuthenticationSession for OAuth-based trackers and handles
/// the callback URL to complete the login flow.
struct TrackerLoginSheet: View {
    let tracker: IdentifiableTracker
    let onLoginSuccess: () -> Void

    @State private var isAuthenticating: Bool = false
    @State private var authError: String? = nil
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                // Tracker identity
                trackerIdentity

                // Description
                Text("Log in to \(tracker.tracker.name) to track your manga reading progress and sync it across devices.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                // Login button
                loginButton

                if let authError {
                    Text(authError)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                Spacer()
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .navigationTitle("Log in")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Subviews

    private var trackerIdentity: some View {
        VStack(spacing: 12) {
            Image(systemName: tracker.tracker.logoName)
                .resizable()
                .scaledToFit()
                .frame(width: 64, height: 64)
                .foregroundStyle(Color.accentColor)
                .padding(16)
                .background(Color.accentColor.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 20))

            Text(tracker.tracker.name)
                .font(.title2)
                .fontWeight(.semibold)
        }
    }

    private var loginButton: some View {
        Button {
            Task { await startAuth() }
        } label: {
            HStack(spacing: 8) {
                if isAuthenticating {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "arrow.right.circle.fill")
                }
                Text(isAuthenticating ? "Authenticating…" : "Log in with \(tracker.tracker.name)")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .padding(.horizontal, 32)
        .disabled(isAuthenticating)
    }

    // MARK: - Authentication

    private func startAuth() async {
        authError = nil
        isAuthenticating = true
        defer { isAuthenticating = false }

        let authUrlString = tracker.tracker.getAuthUrl()
        guard let authURL = URL(string: authUrlString) else {
            authError = "Invalid authentication URL."
            return
        }

        // Derive a callback scheme from the tracker name for the ASWebAuthenticationSession.
        // Trackers must register their custom URL scheme in Info.plist.
        let callbackScheme = callbackURLScheme(for: tracker.tracker)

        do {
            let callbackURL = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
                let session = ASWebAuthenticationSession(
                    url: authURL,
                    callbackURLScheme: callbackScheme
                ) { url, error in
                    if let url {
                        continuation.resume(returning: url)
                    } else if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(throwing: TrackerLoginError.cancelled)
                    }
                }
                session.prefersEphemeralWebBrowserSession = false
                session.start()
            }

            try await tracker.tracker.handleAuthCallback(url: callbackURL)
            dismiss()
            onLoginSuccess()
        } catch TrackerLoginError.cancelled {
            // User cancelled – no error to display.
        } catch {
            authError = error.localizedDescription
        }
    }

    /// Derives the custom URL callback scheme expected by each tracker.
    /// Fallback: lowercased tracker name with non-alphanumeric chars stripped.
    private func callbackURLScheme(for tracker: any Tracker) -> String {
        tracker.name
            .lowercased()
            .components(separatedBy: .alphanumerics.inverted)
            .joined()
    }
}

// MARK: - TrackerLoginError

private enum TrackerLoginError: Error {
    case cancelled

    var localizedDescription: String {
        switch self {
        case .cancelled: return "Authentication was cancelled."
        }
    }
}
