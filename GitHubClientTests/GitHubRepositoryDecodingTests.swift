//
//  GitHubRepositoryDecodingTests.swift
//  GitHubClientTests
//

import XCTest
@testable import GitHubClient

final class GitHubRepositoryDecodingTests: XCTestCase {

    func test_decode_mapsSnakeCaseAndDates() throws {
        let json = """
        {
            "id": 44838949,
            "name": "swift",
            "full_name": "apple/swift",
            "owner": {
                "id": 10639145,
                "login": "apple",
                "avatar_url": "https://avatars.githubusercontent.com/u/10639145",
                "html_url": "https://github.com/apple"
            },
            "html_url": "https://github.com/apple/swift",
            "description": "The Swift Programming Language",
            "language": "C++",
            "stargazers_count": 67890,
            "forks_count": 10123,
            "open_issues_count": 5678,
            "topics": ["swift", "compiler"],
            "created_at": "2015-10-23T21:15:07Z",
            "updated_at": "2026-05-08T12:34:56Z"
        }
        """
        let repo = try JSONDecoder.gitHub.decode(GitHubRepository.self, from: Data(json.utf8))

        XCTAssertEqual(repo.id, 44838949)
        XCTAssertEqual(repo.fullName, "apple/swift")
        XCTAssertEqual(repo.owner.login, "apple")
        XCTAssertEqual(repo.stargazersCount, 67890)
        XCTAssertEqual(repo.forksCount, 10123)
        XCTAssertEqual(repo.openIssuesCount, 5678)
        XCTAssertEqual(repo.language, "C++")
        XCTAssertEqual(repo.topics, ["swift", "compiler"])
        XCTAssertEqual(repo.htmlUrl?.absoluteString, "https://github.com/apple/swift")
        XCTAssertNotNil(repo.createdAt)
        XCTAssertNotNil(repo.updatedAt)
    }

    func test_decode_handlesMissingOptionalFields() throws {
        let json = """
        {
            "id": 1,
            "name": "noopt",
            "full_name": "user/noopt",
            "owner": { "id": 2, "login": "user", "avatar_url": null, "html_url": null },
            "stargazers_count": 0,
            "forks_count": 0
        }
        """
        let repo = try JSONDecoder.gitHub.decode(GitHubRepository.self, from: Data(json.utf8))

        XCTAssertEqual(repo.name, "noopt")
        XCTAssertNil(repo.description)
        XCTAssertNil(repo.language)
        XCTAssertNil(repo.openIssuesCount)
        XCTAssertNil(repo.topics)
        XCTAssertNil(repo.createdAt)
        XCTAssertNil(repo.updatedAt)
    }
}
