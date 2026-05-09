//
//  SearchRepositoriesResponse.swift
//  GitHubClient
//

import Foundation

struct SearchRepositoriesResponse: Decodable {
    let totalCount: Int
    let incompleteResults: Bool
    let items: [GitHubRepository]

    enum CodingKeys: String, CodingKey {
        case totalCount = "total_count"
        case incompleteResults = "incomplete_results"
        case items
    }
}
