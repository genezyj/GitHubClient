//
//  AppCoordinator.swift
//  GitHubClient
//
//  Lightweight composition root. Owns the shared services and constructs
//  the root tab bar with its feature view controllers wired up.
//

import UIKit

@MainActor
final class AppCoordinator {

    static let shared = AppCoordinator()

    let apiClient: APIClientProtocol
    let secureStorage: SecureStorageProtocol
    let gitHubService: GitHubServiceProtocol
    let authService: AuthServiceProtocol
    let biometricAuth: BiometricAuthProtocol
    let oauthService: OAuthServiceProtocol

    private init() {
        let storage = KeychainSecureStorage()
        let client = APIClient()
        let github = GitHubService(client: client, tokenProvider: { try? storage.readToken() })
        let oauth = OAuthService()
        let auth = AuthService(service: github, storage: storage, oauthService: oauth)

        self.secureStorage = storage
        self.apiClient = client
        self.gitHubService = github
        self.oauthService = oauth
        self.authService = auth
        self.biometricAuth = BiometricAuthService()
    }

    func makeRootViewController() -> UIViewController {
        return MainTabBarController(
            gitHubService: gitHubService,
            authService: authService,
            biometricAuth: biometricAuth
        )
    }
}
