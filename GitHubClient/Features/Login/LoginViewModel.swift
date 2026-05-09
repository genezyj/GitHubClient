//
//  LoginViewModel.swift
//  GitHubClient
//

import AuthenticationServices
import Foundation

@MainActor
final class LoginViewModel {

    private let authService: AuthServiceProtocol
    private var loginTask: Task<Void, Never>?

    private(set) var state: ViewState<GitHubUser> = .idle {
        didSet { onStateChange?(state) }
    }

    var onStateChange: ((ViewState<GitHubUser>) -> Void)?

    init(authService: AuthServiceProtocol) {
        self.authService = authService
    }

    /// Kicks off the GitHub OAuth flow. The view controller passes its
    /// window as the presentation anchor so `ASWebAuthenticationSession`
    /// can attach the system sheet correctly.
    func signInWithGitHub(presentationAnchor: ASPresentationAnchor) {
        loginTask?.cancel()
        state = .loading
        loginTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let user = try await self.authService.loginWithGitHub(presentationAnchor: presentationAnchor)
                if Task.isCancelled { return }
                self.state = .loaded(user)
            } catch {
                if Task.isCancelled { return }
                self.state = .error((error as? AppError) ?? .unknown)
            }
        }
    }

    /// Convenience used by the view when it sees a placeholder client ID.
    /// Saves an extra round-trip through ASWebAuthenticationSession only to
    /// fail with an unhelpful GitHub error.
    var hasOAuthCredentials: Bool {
        return !OAuthConfig.isPlaceholderCredentialed
    }
}
