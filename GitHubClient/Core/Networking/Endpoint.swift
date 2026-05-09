//
//  Endpoint.swift
//  GitHubClient
//

import Foundation

struct Endpoint {
    let path: String
    let method: HTTPMethod
    let queryItems: [URLQueryItem]

    init(path: String, method: HTTPMethod = .get, queryItems: [URLQueryItem] = []) {
        self.path = path
        self.method = method
        self.queryItems = queryItems
    }
}

extension Endpoint {

    static func popularSwiftRepositories(page: Int) -> Endpoint {
        return Endpoint(
            path: "/search/repositories",
            queryItems: [
                URLQueryItem(name: "q", value: "language:swift stars:>5000"),
                URLQueryItem(name: "sort", value: "stars"),
                URLQueryItem(name: "order", value: "desc"),
                URLQueryItem(name: "per_page", value: "20"),
                URLQueryItem(name: "page", value: String(page))
            ]
        )
    }

    static func searchRepositories(query: String, page: Int) -> Endpoint {
        return Endpoint(
            path: "/search/repositories",
            queryItems: [
                URLQueryItem(name: "q", value: query),
                URLQueryItem(name: "sort", value: "stars"),
                URLQueryItem(name: "order", value: "desc"),
                URLQueryItem(name: "per_page", value: "20"),
                URLQueryItem(name: "page", value: String(page))
            ]
        )
    }

    static var authenticatedUser: Endpoint {
        return Endpoint(path: "/user")
    }

    static func repository(owner: String, repo: String) -> Endpoint {
        return Endpoint(path: "/repos/\(owner)/\(repo)")
    }
}
