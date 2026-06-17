//
//  RepositoryDetailViewModel.swift
//  GitHubClient
//

import Foundation

@MainActor
final class RepositoryDetailViewModel {

    private let service: GitHubServiceProtocol
    let path: String
    private var loadTask: Task<Void, Never>?
    private var contentsTask: Task<Void, Never>?
    private var starTask: Task<Void, Never>?
    private var toggleStarTask: Task<Void, Never>?

    /// Initial repository (the row tapped in Home / Search). Used for an
    /// instant first paint while the full detail loads in the background.
    private(set) var repository: GitHubRepository

    private(set) var state: ViewState<GitHubRepository> = .idle {
        didSet { onStateChange?(state) }
    }

    private(set) var contentsState: ViewState<[RepositoryContent]> = .idle {
        didSet { onContentsStateChange?(contentsState) }
    }

    private(set) var isStarred: Bool = false {
        didSet { onStarStateChange?(isStarred, isTogglingStar) }
    }

    private(set) var isTogglingStar: Bool = false {
        didSet { onStarStateChange?(isStarred, isTogglingStar) }
    }

    var onStateChange: ((ViewState<GitHubRepository>) -> Void)?
    var onContentsStateChange: ((ViewState<[RepositoryContent]>) -> Void)?
    var onStarStateChange: ((_ isStarred: Bool, _ isToggling: Bool) -> Void)?
    var onStarError: ((AppError) -> Void)?

    init(repository: GitHubRepository, service: GitHubServiceProtocol, path: String = "") {
        self.repository = repository
        self.service = service
        self.path = path
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
        loadContents()
    }

    func loadStarStateIfAuthenticated(isLoggedIn: Bool) {
        starTask?.cancel()
        guard isLoggedIn else {
            isStarred = false
            return
        }
        starTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let starred = try await self.service.isRepositoryStarred(
                    owner: self.repository.owner.login,
                    repo: self.repository.name
                )
                if Task.isCancelled { return }
                self.isStarred = starred
            } catch {
                if Task.isCancelled { return }
                self.isStarred = false
            }
        }
    }

    func toggleStar() {
        toggleStarTask?.cancel()
        let oldValue = isStarred
        isTogglingStar = true
        isStarred.toggle()
        toggleStarTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                if oldValue {
                    try await self.service.unstarRepository(owner: self.repository.owner.login, repo: self.repository.name)
                } else {
                    try await self.service.starRepository(owner: self.repository.owner.login, repo: self.repository.name)
                }
                if Task.isCancelled { return }
                self.isTogglingStar = false
                NotificationCenter.default.post(name: .starredRepositoriesDidChange, object: nil)
            } catch {
                if Task.isCancelled { return }
                self.isStarred = oldValue
                self.isTogglingStar = false
                self.onStarError?((error as? AppError) ?? .unknown)
            }
        }
    }

    func loadContents() {
        contentsTask?.cancel()
        contentsState = .loading
        contentsTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let items = try await self.service.fetchRepositoryContents(
                    owner: self.repository.owner.login,
                    repo: self.repository.name,
                    path: self.path
                )
                if Task.isCancelled { return }
                let sortedItems = Self.sortedContents(items)
                self.contentsState = sortedItems.isEmpty ? .empty : .loaded(sortedItems)
            } catch {
                if Task.isCancelled { return }
                self.contentsState = .error((error as? AppError) ?? .unknown)
            }
        }
    }

    func childViewModel(for directory: RepositoryContent) -> RepositoryDetailViewModel {
        return RepositoryDetailViewModel(repository: repository, service: service, path: directory.path)
    }

    func fileViewModel(for file: RepositoryContent) -> RepositoryFileViewModel {
        return RepositoryFileViewModel(repository: repository, item: file, service: service)
    }

    private static func sortedContents(_ items: [RepositoryContent]) -> [RepositoryContent] {
        return items.sorted { lhs, rhs in
            if lhs.isDirectory != rhs.isDirectory {
                return lhs.isDirectory
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }
}

extension Notification.Name {
    static let starredRepositoriesDidChange = Notification.Name("StarredRepositoriesDidChange")
}
