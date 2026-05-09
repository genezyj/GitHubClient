//
//  SearchViewModel.swift
//  GitHubClient
//

import Foundation

@MainActor
final class SearchViewModel {

    private let service: GitHubServiceProtocol
    private var searchTask: Task<Void, Never>?
    private var nextPageTask: Task<Void, Never>?

    static let pageSize = 20

    private(set) var items: [GitHubRepository] = []
    private(set) var currentPage: Int = 0
    private(set) var currentQuery: String = ""
    private(set) var isLoadingNextPage: Bool = false {
        didSet { onPaginationChange?(isLoadingNextPage, hasMore) }
    }
    private(set) var hasMore: Bool = false {
        didSet { onPaginationChange?(isLoadingNextPage, hasMore) }
    }

    private(set) var state: ViewState<[GitHubRepository]> = .idle {
        didSet { onStateChange?(state) }
    }

    var onStateChange: ((ViewState<[GitHubRepository]>) -> Void)?
    var onPaginationChange: ((_ isLoadingNextPage: Bool, _ hasMore: Bool) -> Void)?

    init(service: GitHubServiceProtocol) {
        self.service = service
    }

    func reset() {
        searchTask?.cancel()
        nextPageTask?.cancel()
        items.removeAll()
        currentPage = 0
        currentQuery = ""
        hasMore = false
        isLoadingNextPage = false
        state = .idle
    }

    func search(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            reset()
            return
        }

        searchTask?.cancel()
        nextPageTask?.cancel()
        items.removeAll()
        currentPage = 0
        currentQuery = trimmed
        hasMore = true
        isLoadingNextPage = false
        state = .loading
        searchTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let repos = try await self.service.searchRepositories(query: trimmed, page: 1)
                if Task.isCancelled { return }
                guard self.currentQuery == trimmed else { return }
                self.items = repos
                self.currentPage = 1
                self.hasMore = repos.count >= Self.pageSize
                if repos.isEmpty {
                    self.state = .empty
                } else {
                    self.state = .loaded(self.items)
                }
            } catch {
                if Task.isCancelled { return }
                guard self.currentQuery == trimmed else { return }
                self.hasMore = false
                self.state = .error((error as? AppError) ?? .unknown)
            }
        }
    }

    /// Re-run the current query as a fresh first page (pull-to-refresh).
    func refresh() {
        let query = currentQuery
        guard !query.isEmpty else { return }
        search(query: query)
    }

    func loadNextPageIfNeeded() {
        guard hasMore, !isLoadingNextPage, !items.isEmpty, !currentQuery.isEmpty else { return }
        guard case .loaded = state else { return }

        isLoadingNextPage = true
        let nextPage = currentPage + 1
        let query = currentQuery
        nextPageTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let repos = try await self.service.searchRepositories(query: query, page: nextPage)
                if Task.isCancelled { return }
                guard self.currentQuery == query else { return }
                self.appendUnique(repos)
                self.currentPage = nextPage
                self.hasMore = repos.count >= Self.pageSize
                self.state = .loaded(self.items)
            } catch {
                if Task.isCancelled { return }
                self.hasMore = false
            }
            self.isLoadingNextPage = false
        }
    }

    private func appendUnique(_ repos: [GitHubRepository]) {
        let existingIDs = Set(items.map(\.id))
        items.append(contentsOf: repos.filter { !existingIDs.contains($0.id) })
    }
}
