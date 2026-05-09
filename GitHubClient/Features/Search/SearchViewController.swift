//
//  SearchViewController.swift
//  GitHubClient
//

import UIKit

final class SearchViewController: UIViewController {

    private let viewModel: SearchViewModel
    private let searchController = UISearchController(searchResultsController: nil)

    var onSelectRepository: ((GitHubRepository) -> Void)?

    private let tableView = UITableView(frame: .zero, style: .plain)
    private let loadingView = LoadingView()
    private let errorStateView = ErrorStateView()
    private let initialEmptyView = EmptyStateView()
    private let noResultsView = EmptyStateView()
    private let refreshControl = UIRefreshControl()
    private let footerSpinner = UIActivityIndicatorView(style: .medium)

    private var repositories: [GitHubRepository] = []
    private var lastQuery: String = ""

    init(viewModel: SearchViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = L10n.searchTitle
        setupSearchController()
        setupViews()
        bindViewModel()
        render(.idle)
    }

    private func setupSearchController() {
        searchController.searchResultsUpdater = nil
        searchController.searchBar.delegate = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = L10n.searchPlaceholder
        searchController.searchBar.autocapitalizationType = .none
        searchController.searchBar.autocorrectionType = .no
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false
        definesPresentationContext = true
    }

    private func setupViews() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(RepositoryListCell.self, forCellReuseIdentifier: RepositoryListCell.reuseIdentifier)
        tableView.separatorStyle = .none
        tableView.estimatedRowHeight = 160
        tableView.rowHeight = UITableView.automaticDimension
        tableView.backgroundColor = .systemBackground
        tableView.keyboardDismissMode = .onDrag
        tableView.refreshControl = refreshControl
        if UITestingConfiguration.isRunningUITests {
            tableView.accessibilityIdentifier = UITestingAccessibilityID.searchRepositoryList
            searchController.searchBar.searchTextField.accessibilityIdentifier = UITestingAccessibilityID.searchQueryField
        }
        refreshControl.addTarget(self, action: #selector(didPullToRefresh), for: .valueChanged)

        footerSpinner.frame = CGRect(x: 0, y: 0, width: 320, height: 44)
        footerSpinner.hidesWhenStopped = true
        view.addSubview(tableView)

        for v in [loadingView, errorStateView, initialEmptyView, noResultsView] {
            v.translatesAutoresizingMaskIntoConstraints = false
            v.isHidden = true
            view.addSubview(v)
        }

        initialEmptyView.configure(title: L10n.searchInitialEmpty, systemImage: "magnifyingglass")
        noResultsView.configure(title: L10n.searchNoResults, systemImage: "tray")
        errorStateView.onRetry = { [weak self] in
            guard let self else { return }
            self.viewModel.search(query: self.lastQuery)
        }

        let pinned: [UIView] = [tableView, loadingView, errorStateView, initialEmptyView, noResultsView]
        for v in pinned {
            NSLayoutConstraint.activate([
                v.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
                v.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                v.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                v.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
        }
    }

    private func bindViewModel() {
        viewModel.onStateChange = { [weak self] state in
            self?.render(state)
        }
        viewModel.onPaginationChange = { [weak self] isLoadingNext, _ in
            self?.updateFooter(isLoadingNext: isLoadingNext)
        }
    }

    @objc private func didPullToRefresh() {
        guard !lastQuery.isEmpty else {
            refreshControl.endRefreshing()
            return
        }
        viewModel.refresh()
    }

    private func updateFooter(isLoadingNext: Bool) {
        if isLoadingNext {
            tableView.tableFooterView = footerSpinner
            footerSpinner.startAnimating()
        } else {
            footerSpinner.stopAnimating()
            tableView.tableFooterView = nil
        }
    }

    private func render(_ state: ViewState<[GitHubRepository]>) {
        if case .loading = state {} else if refreshControl.isRefreshing {
            refreshControl.endRefreshing()
        }

        let allOverlays = [loadingView, errorStateView, initialEmptyView, noResultsView]
        switch state {
        case .idle:
            repositories = []
            tableView.reloadData()
            tableView.isHidden = true
            allOverlays.forEach { $0.isHidden = true }
            initialEmptyView.isHidden = false
        case .loading:
            if repositories.isEmpty {
                tableView.isHidden = true
                allOverlays.forEach { $0.isHidden = true }
                loadingView.isHidden = false
            }
        case .loaded(let repos):
            repositories = repos
            tableView.reloadData()
            tableView.isHidden = false
            allOverlays.forEach { $0.isHidden = true }
        case .empty:
            repositories = []
            tableView.reloadData()
            tableView.isHidden = true
            allOverlays.forEach { $0.isHidden = true }
            noResultsView.isHidden = false
        case .error(let appError):
            if repositories.isEmpty {
                tableView.isHidden = true
                allOverlays.forEach { $0.isHidden = true }
                errorStateView.configure(title: L10n.errorTitle, message: appError.localizedMessage)
                errorStateView.isHidden = false
            }
        }
    }
}

extension SearchViewController: UISearchBarDelegate {
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        let text = searchBar.text ?? ""
        lastQuery = text
        viewModel.search(query: text)
        searchBar.resignFirstResponder()
    }

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            lastQuery = ""
            viewModel.reset()
        }
    }
}

extension SearchViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return repositories.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: RepositoryListCell.reuseIdentifier, for: indexPath) as! RepositoryListCell
        cell.configure(with: repositories[indexPath.row])
        return cell
    }
}

extension SearchViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard repositories.indices.contains(indexPath.row) else { return }
        onSelectRepository?(repositories[indexPath.row])
    }

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if indexPath.row >= repositories.count - 5 {
            viewModel.loadNextPageIfNeeded()
        }
    }
}
