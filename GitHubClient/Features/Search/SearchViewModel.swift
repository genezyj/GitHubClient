//
//  SearchViewModel.swift
//  GitHubClient
//

import Foundation

@MainActor
final class SearchViewModel {

    private let service: GitHubServiceProtocol
    private var searchTask: Task<Void, Never>?

    private(set) var state: ViewState<[GitHubRepository]> = .idle {
        didSet { onStateChange?(state) }
    }

    var onStateChange: ((ViewState<[GitHubRepository]>) -> Void)?

    init(service: GitHubServiceProtocol) {
        self.service = service
    }

    func reset() {
        searchTask?.cancel()
        state = .idle
    }

    func search(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            reset()
            return
        }

        searchTask?.cancel()
        state = .loading
        searchTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let repos = try await self.service.searchRepositories(query: trimmed, page: 1)
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
