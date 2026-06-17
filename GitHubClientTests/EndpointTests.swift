//
//  EndpointTests.swift
//  GitHubClientTests
//

import XCTest
@testable import GitHubClient

final class EndpointTests: XCTestCase {

    func test_searchRepositories_pathAndQueryItems() {
        let endpoint = Endpoint.searchRepositories(query: "alamofire", page: 2)

        XCTAssertEqual(endpoint.path, "/search/repositories")
        XCTAssertEqual(endpoint.method, .get)

        let items = Dictionary(uniqueKeysWithValues: endpoint.queryItems.map { ($0.name, $0.value) })
        XCTAssertEqual(items["q"], "alamofire")
        XCTAssertEqual(items["sort"], "stars")
        XCTAssertEqual(items["order"], "desc")
        XCTAssertEqual(items["per_page"], "20")
        XCTAssertEqual(items["page"], "2")
    }

    func test_popularSwiftRepositories_filtersByLanguageAndStars() {
        let endpoint = Endpoint.popularSwiftRepositories(page: 1)

        XCTAssertEqual(endpoint.path, "/search/repositories")
        let items = Dictionary(uniqueKeysWithValues: endpoint.queryItems.map { ($0.name, $0.value) })
        XCTAssertEqual(items["q"], "language:swift stars:>5000")
        XCTAssertEqual(items["page"], "1")
        XCTAssertEqual(items["per_page"], "20")
    }

    func test_repositoryDetail_pathContainsOwnerAndRepo() {
        let endpoint = Endpoint.repository(owner: "apple", repo: "swift")
        XCTAssertEqual(endpoint.path, "/repos/apple/swift")
        XCTAssertTrue(endpoint.queryItems.isEmpty)
    }

    func test_starredRepositories_pathAndQueryItems() {
        let endpoint = Endpoint.starredRepositories(page: 3)

        XCTAssertEqual(endpoint.path, "/user/starred")
        XCTAssertEqual(endpoint.method, .get)
        let items = Dictionary(uniqueKeysWithValues: endpoint.queryItems.map { ($0.name, $0.value) })
        XCTAssertEqual(items["sort"], "created")
        XCTAssertEqual(items["direction"], "desc")
        XCTAssertEqual(items["per_page"], "20")
        XCTAssertEqual(items["page"], "3")
    }

    func test_starredRepository_pathContainsOwnerAndRepo() {
        let endpoint = Endpoint.starredRepository(owner: "apple", repo: "swift")

        XCTAssertEqual(endpoint.path, "/user/starred/apple/swift")
        XCTAssertEqual(endpoint.method, .get)
    }

    func test_starredEndpoints_bypassLocalCache() {
        // The starred list and the star-status check must read fresh so the
        // Profile list and star button update right after starring/unstarring.
        XCTAssertEqual(Endpoint.starredRepositories(page: 1).cachePolicy, .reloadIgnoringLocalCacheData)
        XCTAssertEqual(Endpoint.starredRepository(owner: "apple", repo: "swift").cachePolicy, .reloadIgnoringLocalCacheData)
    }

    func test_defaultEndpoint_usesProtocolCachePolicy() {
        XCTAssertEqual(Endpoint.searchRepositories(query: "swift", page: 1).cachePolicy, .useProtocolCachePolicy)
        XCTAssertEqual(Endpoint.repository(owner: "apple", repo: "swift").cachePolicy, .useProtocolCachePolicy)
    }

    func test_repositoryContents_encodesPathComponents() {
        let endpoint = Endpoint.repositoryContents(owner: "space org", repo: "swift repo", path: "Sources/My File.swift")

        XCTAssertEqual(endpoint.path, "/repos/space%20org/swift%20repo/contents/Sources/My%20File.swift")
        XCTAssertEqual(endpoint.acceptHeader, "application/vnd.github+json")
    }

    func test_renderedRepositoryContent_usesHTMLAcceptHeader() {
        let endpoint = Endpoint.renderedRepositoryContent(owner: "apple", repo: "swift", path: "README.md")

        XCTAssertEqual(endpoint.path, "/repos/apple/swift/contents/README.md")
        XCTAssertEqual(endpoint.acceptHeader, "application/vnd.github.html+json")
    }
}
