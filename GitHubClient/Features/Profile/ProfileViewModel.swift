//
//  ProfileViewModel.swift
//  GitHubClient
//

import Foundation

@MainActor
final class ProfileViewModel {

    enum Mode {
        case guest(canUseBiometrics: Bool)
        case loggedIn(GitHubUser)
    }

    private let authService: AuthServiceProtocol
    private let biometricAuth: BiometricAuthProtocol
    private let service: GitHubServiceProtocol
    private var starredTask: Task<Void, Never>?

    private(set) var state: ViewState<Mode> = .idle {
        didSet { onStateChange?(state) }
    }

    private(set) var starredState: ViewState<[GitHubRepository]> = .idle {
        didSet { onStarredStateChange?(starredState) }
    }

    var onStateChange: ((ViewState<Mode>) -> Void)?
    var onStarredStateChange: ((ViewState<[GitHubRepository]>) -> Void)?

    init(authService: AuthServiceProtocol, biometricAuth: BiometricAuthProtocol, service: GitHubServiceProtocol) {
        self.authService = authService
        self.biometricAuth = biometricAuth
        self.service = service
    }

    func refresh() {
        if let user = authService.currentUser {
            state = .loaded(.loggedIn(user))
            loadStarredRepositories()
        } else {
            starredTask?.cancel()
            starredState = .idle
            let canBiometric = biometricAuth.canEvaluateBiometrics() && authService.hasStoredToken
            state = .loaded(.guest(canUseBiometrics: canBiometric))
        }
    }

    func authenticateWithBiometricsAndRestoreSession() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let success = try await self.biometricAuth.authenticate(reason: L10n.loginBiometricReason)
                guard success else { return }
                self.state = .loading
                let user = try await self.authService.restoreSession()
                if let user {
                    self.state = .loaded(.loggedIn(user))
                    self.loadStarredRepositories()
                } else {
                    self.refresh()
                }
            } catch let error as AppError {
                self.state = .error(error)
            } catch {
                // Biometric cancellation / lockouts: fall back to guest state silently.
                self.refresh()
            }
        }
    }

    func logout() {
        do {
            try authService.logout()
        } catch {
            // Even if posting notifications fails, refresh UI.
        }
        starredTask?.cancel()
        starredState = .idle
        refresh()
    }

    /// Deletes the Keychain token; use when the user should not be able to use biometrics to return.
    func revokeStoredLogin() {
        do {
            try authService.revokeStoredLogin()
        } catch {
        }
        starredTask?.cancel()
        starredState = .idle
        refresh()
    }

    func loadStarredRepositories() {
        guard authService.isLoggedIn else {
            starredState = .idle
            return
        }
        starredTask?.cancel()
        starredState = .loading
        starredTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let repos = try await self.service.fetchStarredRepositories(page: 1)
                if Task.isCancelled { return }
                self.starredState = repos.isEmpty ? .empty : .loaded(repos)
            } catch {
                if Task.isCancelled { return }
                self.starredState = .error((error as? AppError) ?? .unknown)
            }
        }
    }
}
