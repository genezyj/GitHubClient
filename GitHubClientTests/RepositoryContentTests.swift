//
//  RepositoryContentTests.swift
//  GitHubClientTests
//

import XCTest
@testable import GitHubClient

final class RepositoryContentTests: XCTestCase {

    func test_decodesDirectoryItem() throws {
        let json = """
        {
            "name": "Sources",
            "path": "Sources",
            "sha": "abc",
            "size": 0,
            "type": "dir",
            "download_url": null,
            "html_url": "https://github.com/apple/swift/tree/main/Sources"
        }
        """

        let item = try JSONDecoder.gitHub.decode(RepositoryContent.self, from: Data(json.utf8))

        XCTAssertEqual(item.name, "Sources")
        XCTAssertEqual(item.type, .dir)
        XCTAssertTrue(item.isDirectory)
        XCTAssertFalse(item.isFile)
    }

    func test_decodesBase64FileContent() throws {
        let encoded = Data("Hello Markdown".utf8).base64EncodedString()
        let json = """
        {
            "name": "README.md",
            "path": "README.md",
            "sha": "abc",
            "size": 14,
            "type": "file",
            "download_url": "https://raw.githubusercontent.com/apple/swift/main/README.md",
            "html_url": "https://github.com/apple/swift/blob/main/README.md",
            "content": "\(encoded)",
            "encoding": "base64"
        }
        """

        let item = try JSONDecoder.gitHub.decode(RepositoryContent.self, from: Data(json.utf8))

        XCTAssertEqual(item.type, .file)
        XCTAssertEqual(item.fileKind, .markdown)
        XCTAssertEqual(item.decodedTextContent, "Hello Markdown")
    }

    func test_classifiesImageAndUnsupportedFiles() {
        XCTAssertEqual(RepositoryContent.fixture(name: "logo.png", path: "logo.png").fileKind, .image)
        XCTAssertEqual(RepositoryContent.fixture(name: "archive.zip", path: "archive.zip").fileKind, .unsupported)
    }
}
