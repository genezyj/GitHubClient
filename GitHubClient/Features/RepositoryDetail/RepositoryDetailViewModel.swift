//
//  RepositoryDetailViewModel.swift
//  GitHubClient
//

import Foundation

@MainActor
final class RepositoryDetailViewModel {

    private let service: GitHubServiceProtocol
    private var loadTask: Task<Void, Never>?

    /// Initial repository (the row tapped in Home / Search). Used for an
    /// instant first paint while the full detail loads in the background.
    private(set) var repository: GitHubRepository

    private(set) var state: ViewState<GitHubRepository> = .idle {
        didSet { onStateChange?(state) }
    }

    var onStateChange: ((ViewState<GitHubRepository>) -> Void)?

    init(repository: GitHubRepository, service: GitHubServiceProtocol) {
        self.repository = repository
        self.service = service
    }

    /// Refresh the repository against `GET /repos/{owner}/{repo}` to pick up
    /// fields the search endpoint omits (e.g. `open_issues_count`).
    func load() {
        loadTask?.cancel()
        // Show what we have immediately; only flip to .loading on a hard
        // refresh request (so users don't see a spinner over a populated UI).
        state = .loaded(repository)
        loadTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let fresh = try await self.service.fetchRepository(
                    owner: self.repository.owner.login,
                    repo: self.repository.name
                )
                if Task.isCancelled { return }
                self.repository = fresh
                self.state = .loaded(fresh)
            } catch {
                if Task.isCancelled { return }
                // Keep the cached row visible; surface the error via state so
                // the VC can decide whether to show a banner / alert.
                self.state = .error((error as? AppError) ?? .unknown)
            }
        }
    }
}
