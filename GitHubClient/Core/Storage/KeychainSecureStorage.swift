//
//  KeychainSecureStorage.swift
//  GitHubClient
//
//  Wraps the system Keychain (Security framework) so the rest of the app
//  never touches `SecItem*` directly. We deliberately use the platform API
//  rather than a third-party wrapper to keep the project free of extra SPM
//  packages and to avoid signing surprises.
//

import Foundation
import Security

enum SecureStorageError: Error {
    case unexpectedStatus(OSStatus)
    case encodingFailed
}

final class KeychainSecureStorage: SecureStorageProtocol {

    private let service: String
    private let account: String

    init(
        service: String = Bundle.main.bundleIdentifier ?? "com.githubclient.keychain",
        account: String = "github.access.token"
    ) {
        self.service = service
        self.account = account
    }

    func saveToken(_ token: String) throws {
        guard let data = token.data(using: .utf8) else {
            throw SecureStorageError.encodingFailed
        }

        let baseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        // Try update first, then add if missing.
        let updateStatus = SecItemUpdate(baseQuery as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess { return }
        if updateStatus == errSecItemNotFound {
            var insertQuery = baseQuery
            insertQuery.merge(attributes) { _, new in new }
            let addStatus = SecItemAdd(insertQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw SecureStorageError.unexpectedStatus(addStatus)
            }
            return
        }
        throw SecureStorageError.unexpectedStatus(updateStatus)
    }

    func readToken() throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        switch status {
        case errSecSuccess:
            guard let data = item as? Data, let token = String(data: data, encoding: .utf8) else {
                return nil
            }
            return token
        case errSecItemNotFound:
            return nil
        default:
            throw SecureStorageError.unexpectedStatus(status)
        }
    }

    func deleteToken() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            throw SecureStorageError.unexpectedStatus(status)
        }
    }
}
