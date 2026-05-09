//
//  HomeViewModel.swift
//  GitHubClient
//

import Foundation

@MainActor
final class HomeViewModel {

    private let service: GitHubServiceProtocol
    private var loadTask: Task<Void, Never>?

    private(set) var state: ViewState<[GitHubRepository]> = .idle {
        didSet { onStateChange?(state) }
    }

    var onStateChange: ((ViewState<[GitHubRepository]>) -> Void)?

    init(service: GitHubServiceProtocol) {
        self.service = service
    }

    func load() {
        loadTask?.cancel()
        state = .loading
        loadTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let repos = try await self.service.fetchPopularSwiftRepositories(page: 1)
                if Task.isCancelled { return }
                if repos.isEmpty {
                    self.state = .empty
                } else {
                    self.state = .loaded(repos)
                }
            } catch {
                if Task.isCancelled { return }
                self.state = .error((error as? AppError) ?? .unknown)
            }
        }
    }
}
