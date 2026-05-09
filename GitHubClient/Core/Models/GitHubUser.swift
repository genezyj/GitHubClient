//
//  GitHubUser.swift
//  GitHubClient
//

import Foundation

struct GitHubUser: Decodable, Hashable {
    let id: Int
    let login: String
    let avatarUrl: URL?
    let htmlUrl: URL?
    let name: String?
    let company: String?
    let blog: String?
    let location: String?
    let email: String?
    let bio: String?
    let publicRepos: Int
    let followers: Int
    let following: Int

    enum CodingKeys: String, CodingKey {
        case id
        case login
        case avatarUrl = "avatar_url"
        case htmlUrl = "html_url"
        case name
        case company
        case blog
        case location
        case email
        case bio
        case publicRepos = "public_repos"
        case followers
        case following
    }
}
