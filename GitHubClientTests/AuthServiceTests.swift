//
//  AuthServiceTests.swift
//  GitHubClientTests
//
//  Exercises the token-validation half of `AuthService`. We don't test
//  the OAuth flow itself since `ASWebAuthenticationSession` requires a
//  real UIWindow.
//

import XCTest
@testable import GitHubClient

@MainActor
final class AuthServiceTests: XCTestCase {

    func test_restoreSession_withValidStoredToken_returnsUserAndUpdatesState() async throws {
        let storage = InMemorySecureStorage(initialToken: "stored-token")
        let service = MockGitHubService()
        let user = GitHubUser.fixture(login: "octocat")
        service.userResult = .success(user)

        let auth = AuthService(
            service: service,
            storage: storage,
            oauthService: StubOAuthService()
        )

        let restored = try await auth.restoreSession()

        XCTAssertEqual(restored?.login, "octocat")
        XCTAssertTrue(auth.isLoggedIn)
        XCTAssertEqual(auth.currentUser?.login, "octocat")
        XCTAssertEqual(service.lastTokenUsedForUser, "stored-token")
    }

    func test_restoreSession_withNoStoredToken_returnsNil() async throws {
        let auth = AuthService(
            service: MockGitHubService(),
            storage: InMemorySecureStorage(initialToken: nil),
            oauthService: StubOAuthService()
        )

        let restored = try await auth.restoreSession()

        XCTAssertNil(restored)
        XCTAssertFalse(auth.isLoggedIn)
    }

    func test_restoreSession_withInvalidToken_throwsUnauthorized() async {
        let storage = InMemorySecureStorage(initialToken: "bad-token")
        let service = MockGitHubService()
        service.userResult = .failure(AppError.unauthorized)

        let auth = AuthService(
            service: service,
            storage: storage,
            oauthService: StubOAuthService()
        )

        do {
            _ = try await auth.restoreSession()
            XCTFail("Expected restoreSession to throw")
        } catch let error as AppError {
            XCTAssertEqual(error, .unauthorized)
        } catch {
            XCTFail("Expected AppError.unauthorized, got \(error)")
        }
        XCTAssertFalse(auth.isLoggedIn)
    }

    func test_logout_clearsTokenAndCurrentUser() async throws {
        let storage = InMemorySecureStorage(initialToken: "stored-token")
        let service = MockGitHubService()
        service.userResult = .success(.fixture())

        let auth = AuthService(
            service: service,
            storage: storage,
            oauthService: StubOAuthService()
        )
        _ = try await auth.restoreSession()
        XCTAssertTrue(auth.isLoggedIn)

        try auth.logout()

        XCTAssertFalse(auth.isLoggedIn)
        XCTAssertNil(auth.currentUser)
        XCTAssertNil(storage.storedToken)
    }
}
