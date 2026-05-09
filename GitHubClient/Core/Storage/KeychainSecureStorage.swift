//
//  KeychainSecureStorage.swift
//  GitHubClient
//
//  OAuth token storage behind `SecureStorageProtocol`, implemented with the
//  KeychainAccess library (same semantics as before: generic password scoped
//  by bundle service id + fixed account key, `afterFirstUnlockThisDeviceOnly`).
//

import Foundation
import KeychainAccess

enum SecureStorageError: Error {
    /// Wraps failures from KeychainAccess / Security framework.
    case keychainUnderlying(Error)
}

final class KeychainSecureStorage: SecureStorageProtocol {

    private let account: String
    private let keychain: Keychain

    init(
        service: String = Bundle.main.bundleIdentifier ?? "com.githubclient.keychain",
        account: String = "github.access.token"
    ) {
        self.account = account
        self.keychain = Keychain(service: service).accessibility(.afterFirstUnlockThisDeviceOnly)
    }

    func saveToken(_ token: String) throws {
        do {
            try keychain.set(token, key: account)
        } catch {
            throw SecureStorageError.keychainUnderlying(error)
        }
    }

    func readToken() throws -> String? {
        do {
            return try keychain.get(account)
        } catch {
            throw SecureStorageError.keychainUnderlying(error)
        }
    }

    func deleteToken() throws {
        do {
            try keychain.remove(account)
        } catch {
            throw SecureStorageError.keychainUnderlying(error)
        }
    }
}
