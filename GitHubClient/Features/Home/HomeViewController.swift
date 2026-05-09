//
//  HomeViewController.swift
//  GitHubClient
//

import UIKit

final class HomeViewController: UIViewController {

    private let viewModel: HomeViewModel

    private let tableView = UITableView(frame: .zero, style: .plain)
    private let loadingView = LoadingView()
    private let errorStateView = ErrorStateView()
    private let emptyStateView = EmptyStateView()

    private var repositories: [GitHubRepository] = []

    init(viewModel: HomeViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = L10n.homeTitle
        setupViews()
        bindViewModel()
        viewModel.load()
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
        view.addSubview(tableView)

        for v in [loadingView, errorStateView, emptyStateView] {
            v.translatesAutoresizingMaskIntoConstraints = false
            v.isHidden = true
            view.addSubview(v)
        }

        emptyStateView.configure(title: L10n.searchNoResults, systemImage: "tray")
        errorStateView.onRetry = { [weak self] in self?.viewModel.load() }

        let pinned: [UIView] = [tableView, loadingView, errorStateView, emptyStateView]
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
    }

    private func render(_ state: ViewState<[GitHubRepository]>) {
        switch state {
        case .idle:
            tableView.isHidden = true
            loadingView.isHidden = true
            errorStateView.isHidden = true
            emptyStateView.isHidden = true
        case .loading:
            tableView.isHidden = true
            errorStateView.isHidden = true
            emptyStateView.isHidden = true
            loadingView.isHidden = false
        case .loaded(let repos):
            repositories = repos
            tableView.reloadData()
            tableView.isHidden = false
            loadingView.isHidden = true
            errorStateView.isHidden = true
            emptyStateView.isHidden = true
        case .empty:
            tableView.isHidden = true
            loadingView.isHidden = true
            errorStateView.isHidden = true
            emptyStateView.isHidden = false
        case .error(let appError):
            tableView.isHidden = true
            loadingView.isHidden = true
            emptyStateView.isHidden = true
            errorStateView.configure(
                title: L10n.errorTitle,
                message: appError.localizedMessage
            )
            errorStateView.isHidden = false
        }
    }
}

extension HomeViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return repositories.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: RepositoryListCell.reuseIdentifier, for: indexPath) as! RepositoryListCell
        cell.configure(with: repositories[indexPath.row])
        return cell
    }
}

extension HomeViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
}
