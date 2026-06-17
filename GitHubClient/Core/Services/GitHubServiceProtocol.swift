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
    func fetchStarredRepositories(page: Int) async throws -> [GitHubRepository]
    func isRepositoryStarred(owner: String, repo: String) async throws -> Bool
    func starRepository(owner: String, repo: String) async throws
    func unstarRepository(owner: String, repo: String) async throws
    func fetchRepositoryContents(owner: String, repo: String, path: String) async throws -> [RepositoryContent]
    func fetchRepositoryFile(owner: String, repo: String, path: String) async throws -> RepositoryContent
    func fetchRenderedMarkdownHTML(owner: String, repo: String, path: String) async throws -> String
}
