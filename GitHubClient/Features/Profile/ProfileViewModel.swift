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

    private(set) var state: ViewState<Mode> = .idle {
        didSet { onStateChange?(state) }
    }

    var onStateChange: ((ViewState<Mode>) -> Void)?

    init(authService: AuthServiceProtocol, biometricAuth: BiometricAuthProtocol) {
        self.authService = authService
        self.biometricAuth = biometricAuth
    }

    func refresh() {
        if let user = authService.currentUser {
            state = .loaded(.loggedIn(user))
        } else {
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
        refresh()
    }

    /// Deletes the Keychain token; use when the user should not be able to use biometrics to return.
    func revokeStoredLogin() {
        do {
            try authService.revokeStoredLogin()
        } catch {
        }
        refresh()
    }
}
