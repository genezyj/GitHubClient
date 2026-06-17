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
    var starredRepositoriesResult: Result<[GitHubRepository], Error> = .success([])
    var isStarredResult: Result<Bool, Error> = .success(false)
    var starResult: Result<Void, Error> = .success(())
    var unstarResult: Result<Void, Error> = .success(())
    var contentsResult: Result<[RepositoryContent], Error> = .success([])
    var fileResult: Result<RepositoryContent, Error> = .failure(AppError.notFound)
    var renderedHTMLResult: Result<String, Error> = .success("<p>Hello</p>")

    private(set) var lastSearchQuery: String?
    private(set) var lastSearchPage: Int?
    private(set) var lastTokenUsedForUser: String?
    private(set) var lastContentsPath: String?
    private(set) var didStarRepository = false
    private(set) var didUnstarRepository = false

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

    func fetchStarredRepositories(page: Int) async throws -> [GitHubRepository] {
        try starredRepositoriesResult.get()
    }

    func isRepositoryStarred(owner: String, repo: String) async throws -> Bool {
        try isStarredResult.get()
    }

    func starRepository(owner: String, repo: String) async throws {
        didStarRepository = true
        try starResult.get()
    }

    func unstarRepository(owner: String, repo: String) async throws {
        didUnstarRepository = true
        try unstarResult.get()
    }

    func fetchRepositoryContents(owner: String, repo: String, path: String) async throws -> [RepositoryContent] {
        lastContentsPath = path
        return try contentsResult.get()
    }

    func fetchRepositoryFile(owner: String, repo: String, path: String) async throws -> RepositoryContent {
        lastContentsPath = path
        return try fileResult.get()
    }

    func fetchRenderedMarkdownHTML(owner: String, repo: String, path: String) async throws -> String {
        lastContentsPath = path
        return try renderedHTMLResult.get()
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

struct StubBiometricAuth: BiometricAuthProtocol {
    var canEvaluate = false
    var authenticateResult = true

    func canEvaluateBiometrics() -> Bool { canEvaluate }
    func authenticate(reason: String) async throws -> Bool { authenticateResult }
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

extension RepositoryContent {
    static func fixture(
        name: String = "README.md",
        path: String = "README.md",
        type: String = "file",
        size: Int? = 12,
        content: String? = nil,
        encoding: String? = nil
    ) -> RepositoryContent {
        let json = """
        {
            "name": "\(name)",
            "path": "\(path)",
            "sha": "abc123",
            "size": \(size ?? 0),
            "type": "\(type)",
            "download_url": "https://raw.githubusercontent.com/apple/swift/main/\(path)",
            "html_url": "https://github.com/apple/swift/blob/main/\(path)",
            "content": \(content.map { "\"\($0)\"" } ?? "null"),
            "encoding": \(encoding.map { "\"\($0)\"" } ?? "null")
        }
        """
        let data = Data(json.utf8)
        return try! JSONDecoder.gitHub.decode(RepositoryContent.self, from: data)
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
