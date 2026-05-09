//
//  TestMocks.swift
//  GitHubClientTests
//
//  Tiny in-memory fakes for the protocols the unit tests need. Keeping
//  them in a single file avoids ceremony — these are demonstration
//  tests, not a production mocking framework.
//

import AuthenticationServices
import Foundation
@testable import GitHubClient

/// In-memory replacement for `GitHubServiceProtocol`. Tests poke the
/// `*Result` properties before exercising the code under test.
final class MockGitHubService: GitHubServiceProtocol, @unchecked Sendable {
    var popularResult: Result<[GitHubRepository], Error> = .success([])
    var searchResult: Result<[GitHubRepository], Error> = .success([])
    var userResult: Result<GitHubUser, Error> = .failure(AppError.unauthorized)
    var repositoryResult: Result<GitHubRepository, Error> = .failure(AppError.notFound)

    private(set) var lastSearchQuery: String?
    private(set) var lastSearchPage: Int?
    private(set) var lastTokenUsedForUser: String?

    func fetchPopularSwiftRepositories(page: Int) async throws -> [GitHubRepository] {
        try popularResult.get()
    }

    func searchRepositories(query: String, page: Int) async throws -> [GitHubRepository] {
        lastSearchQuery = query
        lastSearchPage = page
        return try searchResult.get()
    }

    func fetchAuthenticatedUser(token: String) async throws -> GitHubUser {
        lastTokenUsedForUser = token
        return try userResult.get()
    }

    func fetchRepository(owner: String, repo: String) async throws -> GitHubRepository {
        try repositoryResult.get()
    }
}

/// In-memory `SecureStorageProtocol` that behaves like a single-slot
/// Keychain.
final class InMemorySecureStorage: SecureStorageProtocol, @unchecked Sendable {
    private(set) var storedToken: String?

    init(initialToken: String? = nil) {
        self.storedToken = initialToken
    }

    func saveToken(_ token: String) throws { storedToken = token }
    func readToken() throws -> String? { storedToken }
    func deleteToken() throws { storedToken = nil }
}

/// `OAuthService` stub — never invoked by the tests we ship, but
/// required to construct `AuthService`.
final class StubOAuthService: OAuthServiceProtocol, @unchecked Sendable {
    func authenticate(presentationAnchor: ASPresentationAnchor) async throws -> String {
        throw AppError.oauthCancelled
    }
}

extension GitHubUser {
    static func fixture(login: String = "octocat", id: Int = 1) -> GitHubUser {
        let json = """
        {
            "id": \(id),
            "login": "\(login)",
            "name": "The Octocat",
            "avatar_url": "https://avatars.githubusercontent.com/u/\(id)",
            "html_url": "https://github.com/\(login)",
            "company": null,
            "blog": null,
            "location": null,
            "email": null,
            "bio": null,
            "public_repos": 12,
            "followers": 100,
            "following": 7
        }
        """
        let data = Data(json.utf8)
        return try! JSONDecoder.gitHub.decode(GitHubUser.self, from: data)
    }
}

extension GitHubRepository {
    static func fixture(id: Int = 1, name: String = "swift") -> GitHubRepository {
        let json = """
        {
            "id": \(id),
            "name": "\(name)",
            "full_name": "apple/\(name)",
            "owner": {
                "id": 10639145,
                "login": "apple",
                "avatar_url": "https://avatars.githubusercontent.com/u/10639145",
                "html_url": "https://github.com/apple"
            },
            "html_url": "https://github.com/apple/\(name)",
            "description": "The Swift Programming Language",
            "language": "C++",
            "stargazers_count": 70000,
            "forks_count": 11000,
            "open_issues_count": 1500,
            "topics": ["swift", "compiler"],
            "created_at": "2015-10-23T21:15:07Z",
            "updated_at": "2026-05-08T12:34:56Z"
        }
        """
        let data = Data(json.utf8)
        return try! JSONDecoder.gitHub.decode(GitHubRepository.self, from: data)
    }
}

/// JSON decoder configured the same way as `APIClient`.
extension JSONDecoder {
    static var gitHub: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
