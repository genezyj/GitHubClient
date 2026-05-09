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
}
