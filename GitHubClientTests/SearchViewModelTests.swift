//
//  SearchViewModelTests.swift
//  GitHubClientTests
//

import XCTest
@testable import GitHubClient

@MainActor
final class SearchViewModelTests: XCTestCase {

    func test_search_success_emitsLoadingThenLoaded() async {
        let service = MockGitHubService()
        let repos = [
            GitHubRepository.fixture(id: 1, name: "alpha"),
            GitHubRepository.fixture(id: 2, name: "beta")
        ]
        service.searchResult = .success(repos)

        let viewModel = SearchViewModel(service: service)
        var observed: [String] = []
        let loaded = expectation(description: "reaches .loaded")

        viewModel.onStateChange = { state in
            switch state {
            case .idle:    observed.append("idle")
            case .loading: observed.append("loading")
            case .loaded:  observed.append("loaded"); loaded.fulfill()
            case .empty:   observed.append("empty")
            case .error:   observed.append("error")
            }
        }

        viewModel.search(query: "swift")
        await fulfillment(of: [loaded], timeout: 1.0)

        XCTAssertEqual(observed.first, "loading")
        XCTAssertEqual(observed.last, "loaded")
        XCTAssertEqual(viewModel.items.count, 2)
        XCTAssertEqual(service.lastSearchQuery, "swift")
        XCTAssertEqual(service.lastSearchPage, 1)
    }

    func test_search_failure_emitsLoadingThenError() async {
        let service = MockGitHubService()
        service.searchResult = .failure(AppError.network("offline"))

        let viewModel = SearchViewModel(service: service)
        var observed: [String] = []
        let errored = expectation(description: "reaches .error")

        viewModel.onStateChange = { state in
            switch state {
            case .idle:    observed.append("idle")
            case .loading: observed.append("loading")
            case .loaded:  observed.append("loaded")
            case .empty:   observed.append("empty")
            case .error:   observed.append("error"); errored.fulfill()
            }
        }

        viewModel.search(query: "swift")
        await fulfillment(of: [errored], timeout: 1.0)

        XCTAssertEqual(observed.first, "loading")
        XCTAssertEqual(observed.last, "error")
        XCTAssertTrue(viewModel.items.isEmpty)
        XCTAssertFalse(viewModel.hasMore)
    }

    func test_emptyQuery_resetsToIdle() {
        let viewModel = SearchViewModel(service: MockGitHubService())
        viewModel.search(query: "   ")
        guard case .idle = viewModel.state else {
            XCTFail("Expected .idle for empty query, got \(viewModel.state)")
            return
        }
    }
}
