//
//  GitHubRepository.swift
//  GitHubClient
//

import Foundation

struct GitHubRepository: Decodable, Hashable {
    let id: Int
    let name: String
    let fullName: String
    let owner: RepositoryOwner
    let htmlUrl: URL?
    let description: String?
    let language: String?
    let stargazersCount: Int
    let forksCount: Int
    let openIssuesCount: Int?
    let topics: [String]?
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case fullName = "full_name"
        case owner
        case htmlUrl = "html_url"
        case description
        case language
        case stargazersCount = "stargazers_count"
        case forksCount = "forks_count"
        case openIssuesCount = "open_issues_count"
        case topics
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
