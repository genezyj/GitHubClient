//
//  HomeViewModel.swift
//  GitHubClient
//

import Foundation

@MainActor
final class HomeViewModel {

    private let service: GitHubServiceProtocol
    private var loadTask: Task<Void, Never>?
    private var nextPageTask: Task<Void, Never>?

    /// Per-request page size. GitHub's search API caps at 100; 20 keeps the
    /// payload light and matches PROJECT_SPEC §11.
    static let pageSize = 20

    private(set) var items: [GitHubRepository] = []
    private(set) var currentPage: Int = 0
    private(set) var isLoadingNextPage: Bool = false {
        didSet { onPaginationChange?(isLoadingNextPage, hasMore) }
    }
    private(set) var hasMore: Bool = true {
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

    /// Load the first page from scratch (initial load + pull-to-refresh).
    func load() {
        nextPageTask?.cancel()
        loadTask?.cancel()
        items.removeAll()
        currentPage = 0
        hasMore = true
        isLoadingNextPage = false
        state = .loading
        loadTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let repos = try await self.service.fetchPopularSwiftRepositories(page: 1)
                if Task.isCancelled { return }
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
                self.hasMore = false
                self.state = .error((error as? AppError) ?? .unknown)
            }
        }
    }

    func loadNextPageIfNeeded() {
        guard hasMore, !isLoadingNextPage, !items.isEmpty else { return }
        guard case .loaded = state else { return }

        isLoadingNextPage = true
        let nextPage = currentPage + 1
        nextPageTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let repos = try await self.service.fetchPopularSwiftRepositories(page: nextPage)
                if Task.isCancelled { return }
                self.appendUnique(repos)
                self.currentPage = nextPage
                self.hasMore = repos.count >= Self.pageSize
                self.state = .loaded(self.items)
            } catch {
                // Keep existing items visible; just stop trying to paginate
                // until the next pull-to-refresh.
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
