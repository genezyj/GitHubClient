//
//  RepositoryOwner.swift
//  GitHubClient
//

import Foundation

struct RepositoryOwner: Decodable, Hashable {
    let id: Int
    let login: String
    let avatarUrl: URL?
    let htmlUrl: URL?

    enum CodingKeys: String, CodingKey {
        case id
        case login
        case avatarUrl = "avatar_url"
        case htmlUrl = "html_url"
    }
}
