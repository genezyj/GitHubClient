//
//  GitHubService.swift
//  GitHubClient
//

import Foundation

final class GitHubService: GitHubServiceProtocol {

    private let client: APIClientProtocol
    private let tokenProvider: () -> String?

    init(client: APIClientProtocol, tokenProvider: @escaping () -> String? = { nil }) {
        self.client = client
        self.tokenProvider = tokenProvider
    }

    func fetchPopularSwiftRepositories(page: Int) async throws -> [GitHubRepository] {
        let response: SearchRepositoriesResponse = try await client.request(
            .popularSwiftRepositories(page: page),
            token: tokenProvider()
        )
        return response.items
    }

    func searchRepositories(query: String, page: Int) async throws -> [GitHubRepository] {
        let response: SearchRepositoriesResponse = try await client.request(
            .searchRepositories(query: query, page: page),
            token: tokenProvider()
        )
        return response.items
    }

    func fetchAuthenticatedUser(token: String) async throws -> GitHubUser {
        return try await client.request(.authenticatedUser, token: token)
    }

    func fetchRepository(owner: String, repo: String) async throws -> GitHubRepository {
        return try await client.request(.repository(owner: owner, repo: repo), token: tokenProvider())
    }

    func fetchStarredRepositories(page: Int) async throws -> [GitHubRepository] {
        return try await client.request(.starredRepositories(page: page), token: tokenProvider())
    }

    func isRepositoryStarred(owner: String, repo: String) async throws -> Bool {
        do {
            let _: EmptyResponse = try await client.request(.starredRepository(owner: owner, repo: repo), token: tokenProvider())
            return true
        } catch AppError.notFound {
            return false
        }
    }

    func starRepository(owner: String, repo: String) async throws {
        let endpoint = Endpoint.starredRepository(owner: owner, repo: repo)
        let request = Endpoint(path: endpoint.path, method: .put, acceptHeader: endpoint.acceptHeader)
        let _: EmptyResponse = try await client.request(request, token: tokenProvider())
    }

    func unstarRepository(owner: String, repo: String) async throws {
        let endpoint = Endpoint.starredRepository(owner: owner, repo: repo)
        let request = Endpoint(path: endpoint.path, method: .delete, acceptHeader: endpoint.acceptHeader)
        let _: EmptyResponse = try await client.request(request, token: tokenProvider())
    }

    func fetchRepositoryContents(owner: String, repo: String, path: String) async throws -> [RepositoryContent] {
        let items: [RepositoryContent] = try await client.request(
            .repositoryContents(owner: owner, repo: repo, path: path),
            token: tokenProvider()
        )
        return items.sorted { lhs, rhs in
            if lhs.isDirectory != rhs.isDirectory {
                return lhs.isDirectory
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    func fetchRepositoryFile(owner: String, repo: String, path: String) async throws -> RepositoryContent {
        return try await client.request(
            .repositoryContents(owner: owner, repo: repo, path: path),
            token: tokenProvider()
        )
    }

    func fetchRenderedMarkdownHTML(owner: String, repo: String, path: String) async throws -> String {
        let data = try await client.requestData(
            .renderedRepositoryContent(owner: owner, repo: repo, path: path),
            token: tokenProvider()
        )
        if let object = try? JSONDecoder().decode(RenderedContentResponse.self, from: data),
           let content = object.content {
            return content
        }
        return String(decoding: data, as: UTF8.self)
    }

    private struct RenderedContentResponse: Decodable {
        let content: String?
    }
}
