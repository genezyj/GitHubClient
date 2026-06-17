//
//  RepositoryBrowserViewModelTests.swift
//  GitHubClientTests
//

import XCTest
@testable import GitHubClient

@MainActor
final class RepositoryBrowserViewModelTests: XCTestCase {

    func test_loadContents_successSortsFoldersBeforeFiles() async {
        let service = MockGitHubService()
        service.contentsResult = .success([
            .fixture(name: "z.swift", path: "z.swift", type: "file"),
            .fixture(name: "Sources", path: "Sources", type: "dir"),
            .fixture(name: "README.md", path: "README.md", type: "file")
        ])
        service.repositoryResult = .success(.fixture())

        let viewModel = RepositoryDetailViewModel(repository: .fixture(), service: service)
        let loaded = expectation(description: "contents loaded")
        viewModel.onContentsStateChange = { state in
            if case .loaded = state {
                loaded.fulfill()
            }
        }

        viewModel.loadContents()
        await fulfillment(of: [loaded], timeout: 1.0)

        guard case .loaded(let items) = viewModel.contentsState else {
            XCTFail("Expected loaded contents")
            return
        }
        XCTAssertEqual(items.map(\.name), ["Sources", "README.md", "z.swift"])
    }

    func test_toggleStar_successCallsStarAPIAndUpdatesState() async {
        let service = MockGitHubService()
        let viewModel = RepositoryDetailViewModel(repository: .fixture(), service: service)
        let toggled = expectation(description: "star toggled")
        viewModel.onStarStateChange = { isStarred, isToggling in
            if isStarred && !isToggling {
                toggled.fulfill()
            }
        }

        viewModel.toggleStar()
        await fulfillment(of: [toggled], timeout: 1.0)

        XCTAssertTrue(viewModel.isStarred)
        XCTAssertTrue(service.didStarRepository)
    }

    func test_toggleStar_failureRollsBack() async {
        let service = MockGitHubService()
        service.starResult = .failure(AppError.forbidden)
        let viewModel = RepositoryDetailViewModel(repository: .fixture(), service: service)
        let errored = expectation(description: "star error")
        viewModel.onStarError = { error in
            XCTAssertEqual(error, .forbidden)
            errored.fulfill()
        }

        viewModel.toggleStar()
        await fulfillment(of: [errored], timeout: 1.0)

        XCTAssertFalse(viewModel.isStarred)
    }

    func test_markdownFileViewModelLoadsRenderedHTML() async {
        let service = MockGitHubService()
        service.renderedHTMLResult = .success("<h1>README</h1>")
        let item = RepositoryContent.fixture(name: "README.md", path: "README.md")
        let viewModel = RepositoryFileViewModel(repository: .fixture(), item: item, service: service)
        let loaded = expectation(description: "markdown loaded")
        viewModel.onStateChange = { state in
            if case .loaded(.markdownHTML(let html)) = state {
                XCTAssertTrue(html.contains("<h1>README</h1>"))
                XCTAssertTrue(html.contains("<meta name=\"viewport\""))
                loaded.fulfill()
            }
        }

        viewModel.load()
        await fulfillment(of: [loaded], timeout: 1.0)

        XCTAssertEqual(service.lastContentsPath, "README.md")
    }

    func test_codeFileViewModelRendersSyntaxHighlightedHTML() async {
        let service = MockGitHubService()
        let encoded = Data("let answer = 42".utf8).base64EncodedString()
        let item = RepositoryContent.fixture(name: "Answer.swift", path: "Sources/Answer.swift", type: "file")
        service.fileResult = .success(.fixture(
            name: "Answer.swift",
            path: "Sources/Answer.swift",
            type: "file",
            content: encoded,
            encoding: "base64"
        ))
        let viewModel = RepositoryFileViewModel(repository: .fixture(), item: item, service: service)
        let loaded = expectation(description: "code loaded")
        viewModel.onStateChange = { state in
            if case .loaded(.codeHTML(let html)) = state {
                XCTAssertTrue(html.contains("let answer = 42"))
                XCTAssertTrue(html.contains("language-swift"))
                XCTAssertTrue(html.contains("highlight.js"))
                loaded.fulfill()
            }
        }

        viewModel.load()
        await fulfillment(of: [loaded], timeout: 1.0)

        XCTAssertEqual(service.lastContentsPath, "Sources/Answer.swift")
    }

    func test_codeFileViewModelEscapesHTMLSpecialCharacters() async {
        let service = MockGitHubService()
        let encoded = Data("if a < b && c > d {}".utf8).base64EncodedString()
        let item = RepositoryContent.fixture(name: "main.swift", path: "main.swift", type: "file")
        service.fileResult = .success(.fixture(
            name: "main.swift",
            path: "main.swift",
            type: "file",
            content: encoded,
            encoding: "base64"
        ))
        let viewModel = RepositoryFileViewModel(repository: .fixture(), item: item, service: service)
        let loaded = expectation(description: "code loaded")
        viewModel.onStateChange = { state in
            if case .loaded(.codeHTML(let html)) = state {
                XCTAssertTrue(html.contains("a &lt; b"))
                XCTAssertTrue(html.contains("&amp;&amp;"))
                XCTAssertTrue(html.contains("c &gt; d"))
                loaded.fulfill()
            }
        }

        viewModel.load()
        await fulfillment(of: [loaded], timeout: 1.0)
    }

    func test_highlightLanguageMapsKnownExtensions() {
        XCTAssertEqual(RepositoryFileViewModel.highlightLanguage(for: "App.swift"), "swift")
        XCTAssertEqual(RepositoryFileViewModel.highlightLanguage(for: "index.ts"), "typescript")
        XCTAssertNil(RepositoryFileViewModel.highlightLanguage(for: "data.bin"))
    }

    func test_childViewModelUsesDirectoryPath() {
        let service = MockGitHubService()
        let viewModel = RepositoryDetailViewModel(repository: .fixture(), service: service, path: "Sources")
        let child = viewModel.childViewModel(for: .fixture(name: "App", path: "Sources/App", type: "dir"))
        XCTAssertEqual(child.path, "Sources/App")
    }
}
