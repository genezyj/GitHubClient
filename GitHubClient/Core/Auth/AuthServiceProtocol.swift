//
//  AuthServiceProtocol.swift
//  GitHubClient
//

import AuthenticationServices
import Foundation

/// Main-thread bound so session updates and `authStateDidChange` posts never
/// run on a background URLSession callback thread.
@MainActor
protocol AuthServiceProtocol: AnyObject {
    var isLoggedIn: Bool { get }
    var currentUser: GitHubUser? { get }
    var hasStoredToken: Bool { get }

    /// Run the GitHub OAuth flow (Authorization Code + PKCE), persist the
    /// resulting access token in the Keychain, validate it against
    /// `GET /user`, and update `currentUser`.
    func loginWithGitHub(presentationAnchor: ASPresentationAnchor) async throws -> GitHubUser

    func restoreSession() async throws -> GitHubUser?

    /// Ends the in-app session but keeps the OAuth token in Keychain so the user can
    /// sign back in with Face ID / Touch ID without repeating OAuth.
    func logout() throws

    /// Deletes the saved token from Keychain and clears the session (no biometric re-entry).
    func revokeStoredLogin() throws
}
