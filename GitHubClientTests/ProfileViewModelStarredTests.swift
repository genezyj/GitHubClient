//
//  ProfileViewModelStarredTests.swift
//  GitHubClientTests
//

import XCTest
@testable import GitHubClient

@MainActor
final class ProfileViewModelStarredTests: XCTestCase {

    func test_refreshLoggedIn_loadsStarredRepositories() async throws {
        let (viewModel, service, auth) = try await makeLoggedInViewModel()
        let repos = [GitHubRepository.fixture(id: 1, name: "swift")]
        service.starredRepositoriesResult = .success(repos)
        let loaded = expectation(description: "starred repos loaded")
        viewModel.onStarredStateChange = { state in
            if case .loaded(let items) = state {
                XCTAssertEqual(items.map(\.name), ["swift"])
                loaded.fulfill()
            }
        }

        XCTAssertTrue(auth.isLoggedIn)
        viewModel.refresh()
        await fulfillment(of: [loaded], timeout: 1.0)
    }

    func test_refreshLoggedIn_emptyStarredRepositories() async throws {
        let (viewModel, service, _) = try await makeLoggedInViewModel()
        service.starredRepositoriesResult = .success([])
        let empty = expectation(description: "starred repos empty")
        viewModel.onStarredStateChange = { state in
            if case .empty = state {
                empty.fulfill()
            }
        }

        viewModel.refresh()
        await fulfillment(of: [empty], timeout: 1.0)
    }

    func test_refreshLoggedIn_starredFailure() async throws {
        let (viewModel, service, _) = try await makeLoggedInViewModel()
        service.starredRepositoriesResult = .failure(AppError.rateLimited)
        let failed = expectation(description: "starred repos failed")
        viewModel.onStarredStateChange = { state in
            if case .error(let error) = state {
                XCTAssertEqual(error, .rateLimited)
                failed.fulfill()
            }
        }

        viewModel.refresh()
        await fulfillment(of: [failed], timeout: 1.0)
    }

    private func makeLoggedInViewModel() async throws -> (ProfileViewModel, MockGitHubService, AuthService) {
        let storage = InMemorySecureStorage(initialToken: "token")
        let service = MockGitHubService()
        service.userResult = .success(.fixture())
        let auth = AuthService(
            service: service,
            storage: storage,
            oauthService: StubOAuthService(),
            sessionTokenGate: SessionTokenGate(storage: storage)
        )
        _ = try await auth.restoreSession()
        let viewModel = ProfileViewModel(
            authService: auth,
            biometricAuth: StubBiometricAuth(),
            service: service
        )
        return (viewModel, service, auth)
    }
}
