//
//  AuthSession.swift
//  GitHubClient
//

import Foundation

/// Lightweight in-memory session description. We deliberately do not persist
/// the user record — only the token is persisted in the Keychain.
struct AuthSession {
    let user: GitHubUser
}
