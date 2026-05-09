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
}
