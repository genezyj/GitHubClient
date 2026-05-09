//
//  GitHubServiceProtocol.swift
//  GitHubClient
//

import Foundation

protocol GitHubServiceProtocol {
    func fetchPopularSwiftRepositories(page: Int) async throws -> [GitHubRepository]
    func searchRepositories(query: String, page: Int) async throws -> [GitHubRepository]
    func fetchAuthenticatedUser(token: String) async throws -> GitHubUser
    func fetchRepository(owner: String, repo: String) async throws -> GitHubRepository
}
