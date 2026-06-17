//
//  Endpoint.swift
//  GitHubClient
//

import Foundation

struct Endpoint {
    let path: String
    let method: HTTPMethod
    let queryItems: [URLQueryItem]
    let acceptHeader: String
    let cachePolicy: URLRequest.CachePolicy

    init(
        path: String,
        method: HTTPMethod = .get,
        queryItems: [URLQueryItem] = [],
        acceptHeader: String = "application/vnd.github+json",
        cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy
    ) {
        self.path = path
        self.method = method
        self.queryItems = queryItems
        self.acceptHeader = acceptHeader
        self.cachePolicy = cachePolicy
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
        return Endpoint(path: "/repos/\(encodedPath(owner, repo))")
    }

    static func starredRepositories(page: Int) -> Endpoint {
        return Endpoint(
            path: "/user/starred",
            queryItems: [
                URLQueryItem(name: "sort", value: "created"),
                URLQueryItem(name: "direction", value: "desc"),
                URLQueryItem(name: "per_page", value: "20"),
                URLQueryItem(name: "page", value: String(page))
            ],
            // GitHub serves this list with `Cache-Control: private, max-age=60`,
            // so the shared URLCache would return a stale list right after the
            // user stars/unstars a repo. Always read it fresh.
            cachePolicy: .reloadIgnoringLocalCacheData
        )
    }

    static func starredRepository(owner: String, repo: String) -> Endpoint {
        // Read fresh so the star button reflects the true server-side state.
        return Endpoint(
            path: "/user/starred/\(encodedPath(owner, repo))",
            cachePolicy: .reloadIgnoringLocalCacheData
        )
    }

    static func repositoryContents(owner: String, repo: String, path: String) -> Endpoint {
        let suffix = pathComponents(from: path).joined(separator: "/")
        let base = "/repos/\(encodedPath(owner, repo))/contents"
        return Endpoint(path: suffix.isEmpty ? base : "\(base)/\(suffix)")
    }

    static func renderedRepositoryContent(owner: String, repo: String, path: String) -> Endpoint {
        let suffix = pathComponents(from: path).joined(separator: "/")
        let base = "/repos/\(encodedPath(owner, repo))/contents"
        return Endpoint(
            path: suffix.isEmpty ? base : "\(base)/\(suffix)",
            acceptHeader: "application/vnd.github.html+json"
        )
    }

    private static func encodedPath(_ components: String...) -> String {
        return components.flatMap(pathComponents).joined(separator: "/")
    }

    private static func pathComponents(from path: String) -> [String] {
        return path
            .split(separator: "/", omittingEmptySubsequences: true)
            .map(String.init)
            .map { component in
                component.addingPercentEncoding(withAllowedCharacters: .githubPathComponentAllowed) ?? component
            }
    }
}

private extension CharacterSet {
    static let githubPathComponentAllowed: CharacterSet = {
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove(charactersIn: "/?#[]@!$&'()*+,;=")
        return allowed
    }()
}
