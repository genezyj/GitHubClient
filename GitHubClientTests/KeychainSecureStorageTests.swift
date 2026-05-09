//
//  KeychainSecureStorageTests.swift
//  GitHubClientTests
//
//  Exercises the real KeychainAccess-backed storage with an isolated service id
//  so tests do not collide with the app’s production key or each other.
//

import XCTest
@testable import GitHubClient

final class KeychainSecureStorageTests: XCTestCase {

    func test_saveReadDelete_roundTrip() throws {
        let service = "com.githubclient.tests.keychain.\(UUID().uuidString)"
        let storage = KeychainSecureStorage(service: service, account: "unit.token")
        let secret = "oauth_like_token_\(UUID().uuidString.prefix(8))"

        try storage.saveToken(secret)
        let read = try storage.readToken()
        XCTAssertEqual(read, secret)

        try storage.deleteToken()
        XCTAssertNil(try storage.readToken())
    }

    func test_overwrite_existingToken_returnsLatest() throws {
        let service = "com.githubclient.tests.keychain.\(UUID().uuidString)"
        let storage = KeychainSecureStorage(service: service, account: "unit.overwrite")

        try storage.saveToken("first")
        try storage.saveToken("second")

        XCTAssertEqual(try storage.readToken(), "second")
        try storage.deleteToken()
    }
}
