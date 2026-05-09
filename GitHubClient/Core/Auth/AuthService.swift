//
//  AuthService.swift
//  GitHubClient
//

import AuthenticationServices
import Foundation

@MainActor
final class AuthService: AuthServiceProtocol {

    private let service: GitHubServiceProtocol
    private let storage: SecureStorageProtocol
    private let oauthService: OAuthServiceProtocol
    private let sessionTokenGate: SessionTokenGate

    private(set) var currentUser: GitHubUser?

    init(
        service: GitHubServiceProtocol,
        storage: SecureStorageProtocol,
        oauthService: OAuthServiceProtocol,
        sessionTokenGate: SessionTokenGate
    ) {
        self.service = service
        self.storage = storage
        self.oauthService = oauthService
        self.sessionTokenGate = sessionTokenGate
        syncSessionGate()
    }

    private func syncSessionGate() {
        sessionTokenGate.setSessionActive(currentUser != nil)
    }

    var isLoggedIn: Bool { currentUser != nil }

    var hasStoredToken: Bool {
        return (try? storage.readToken()) != nil
    }

    /// Drive the GitHub OAuth flow end-to-end: open `ASWebAuthenticationSession`,
    /// exchange the code for a bearer token, persist it, then validate via
    /// `GET /user`.
    func loginWithGitHub(presentationAnchor: ASPresentationAnchor) async throws -> GitHubUser {
        let token = try await oauthService.authenticate(presentationAnchor: presentationAnchor)
        let user: GitHubUser
        do {
            user = try await service.fetchAuthenticatedUser(token: token)
        } catch {
            // Token exchange succeeded but `/user` failed — surface as
            // unauthorized (most likely cause) rather than leaving the
            // unverified token on disk.
            throw (error as? AppError) ?? .unauthorized
        }
        try storage.saveToken(token)
        currentUser = user
        syncSessionGate()
        NotificationCenter.default.post(name: .authStateDidChange, object: nil)
        return user
    }

    /// Reads token from Keychain and validates it. Returns nil if no token is stored.
    /// Throws on validation failure (caller decides whether to delete the stale token).
    func restoreSession() async throws -> GitHubUser? {
        guard let token = try storage.readToken() else { return nil }
        let user = try await service.fetchAuthenticatedUser(token: token)
        currentUser = user
        syncSessionGate()
        NotificationCenter.default.post(name: .authStateDidChange, object: nil)
        return user
    }

    func logout() throws {
        currentUser = nil
        syncSessionGate()
        NotificationCenter.default.post(name: .authStateDidChange, object: nil)
    }

    func revokeStoredLogin() throws {
        try storage.deleteToken()
        currentUser = nil
        syncSessionGate()
        NotificationCenter.default.post(name: .authStateDidChange, object: nil)
    }
}

extension Notification.Name {
    static let authStateDidChange = Notification.Name("AuthStateDidChange")
}

// MARK: - UI Testing (XCUITest mock login)

extension AuthService {
    /// Installs a deterministic user + synthetic token — only when launched with
    /// `-uitesting -uitesting_mock_login`. Used by `LoginViewController`; never calls GitHub.
    func completeUITestingMockSignIn() throws {
        guard UITestingConfiguration.enableMockLoginEntryPoint else {
            throw AppError.unknown
        }
        let user = try UITestingConfiguration.makeMockGitHubUser()
        try storage.saveToken(UITestingConfiguration.mockAccessToken)
        currentUser = user
        syncSessionGate()
        NotificationCenter.default.post(name: .authStateDidChange, object: nil)
    }
}
