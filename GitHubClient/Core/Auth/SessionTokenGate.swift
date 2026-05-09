//
//  SessionTokenGate.swift
//  GitHubClient
//

import Foundation

/// Gates whether `GitHubService` attaches the saved OAuth token to outgoing requests.
/// After a local sign-out, the token may remain in Keychain for Face ID / Touch ID
/// re-entry, but must not be sent on API calls until the session is restored.
final class SessionTokenGate: @unchecked Sendable {

    private let lock = NSLock()
    private var isSessionActive = false
    private let storage: SecureStorageProtocol

    init(storage: SecureStorageProtocol) {
        self.storage = storage
    }

    func setSessionActive(_ active: Bool) {
        lock.lock()
        isSessionActive = active
        lock.unlock()
    }

    /// Safe to call from URLSession callback threads.
    func accessTokenIfSessionActive() -> String? {
        lock.lock()
        let active = isSessionActive
        lock.unlock()
        guard active else { return nil }
        return try? storage.readToken()
    }
}
