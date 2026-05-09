//
//  RepositoryDetailViewController.swift
//  GitHubClient
//

import SafariServices
import UIKit

final class RepositoryDetailViewController: UIViewController {

    private let viewModel: RepositoryDetailViewModel

    private let scrollView = UIScrollView()
    private let contentContainer = UIView()
    private let stack = UIStackView()

    private let avatarView = AvatarImageView()
    private let nameLabel = UILabel()
    private let ownerLabel = UILabel()
    private let descriptionLabel = UILabel()
    private let statsRow = UIStackView()
    private let languageBadge = StatBadgeView()
    private let starsBadge = StatBadgeView()
    private let forksBadge = StatBadgeView()
    private let issuesBadge = StatBadgeView()
    private let topicsLabel = UILabel()
    private let datesLabel = UILabel()
    private let openOnGitHubButton: UIButton = {
        if #available(iOS 15.0, *) {
            var config = UIButton.Configuration.tinted()
            config.image = UIImage(systemName: "safari")
            config.imagePadding = 8
            return UIButton(configuration: config)
        }
        let button = UIButton(type: .system)
        button.layer.cornerRadius = 10
        return button
    }()

    init(viewModel: RepositoryDetailViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = viewModel.repository.fullName
        navigationItem.largeTitleDisplayMode = .never
        setupViews()
        bindViewModel()
        viewModel.load()
    }

    // MARK: Layout

    private func setupViews() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        contentContainer.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentContainer)
        let widthConstraint = contentContainer.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        widthConstraint.priority = .defaultHigh
        NSLayoutConstraint.activate([
            contentContainer.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentContainer.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentContainer.centerXAnchor.constraint(equalTo: scrollView.centerXAnchor),
            widthConstraint,
            contentContainer.widthAnchor.constraint(lessThanOrEqualToConstant: 700)
        ])

        stack.axis = .vertical
        stack.spacing = 14
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentContainer.topAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor, constant: -20),
            stack.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor, constant: -32)
        ])

        avatarView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            avatarView.widthAnchor.constraint(equalToConstant: 56),
            avatarView.heightAnchor.constraint(equalToConstant: 56)
        ])

        nameLabel.font = .preferredFont(forTextStyle: .title2)
        nameLabel.textColor = .label
        nameLabel.numberOfLines = 0
        ownerLabel.font = .preferredFont(forTextStyle: .subheadline)
        ownerLabel.textColor = .secondaryLabel

        let titleStack = UIStackView(arrangedSubviews: [nameLabel, ownerLabel])
        titleStack.axis = .vertical
        titleStack.spacing = 2

        let header = UIStackView(arrangedSubviews: [avatarView, titleStack])
        header.axis = .horizontal
        header.spacing = 12
        header.alignment = .center

        descriptionLabel.font = .preferredFont(forTextStyle: .body)
        descriptionLabel.textColor = .label
        descriptionLabel.numberOfLines = 0

        statsRow.axis = .horizontal
        statsRow.spacing = 16
        statsRow.alignment = .center
        for badge in [languageBadge, starsBadge, forksBadge, issuesBadge] {
            statsRow.addArrangedSubview(badge)
        }
        statsRow.addArrangedSubview(UIView())

        topicsLabel.font = .preferredFont(forTextStyle: .footnote)
        topicsLabel.textColor = .secondaryLabel
        topicsLabel.numberOfLines = 0

        datesLabel.font = .preferredFont(forTextStyle: .footnote)
        datesLabel.textColor = .tertiaryLabel
        datesLabel.numberOfLines = 0

        openOnGitHubButton.translatesAutoresizingMaskIntoConstraints = false
        openOnGitHubButton.addTarget(self, action: #selector(didTapOpenOnGitHub), for: .touchUpInside)
        openOnGitHubButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        if #available(iOS 15.0, *) {
            var config = openOnGitHubButton.configuration
            config?.title = L10n.detailOpenOnGitHub
            openOnGitHubButton.configuration = config
        } else {
            openOnGitHubButton.setTitle(L10n.detailOpenOnGitHub, for: .normal)
        }

        for view in [header, descriptionLabel, statsRow, topicsLabel, datesLabel, openOnGitHubButton] {
            stack.addArrangedSubview(view)
        }
    }

    private func bindViewModel() {
        viewModel.onStateChange = { [weak self] state in
            self?.render(state)
        }
    }

    // MARK: Render

    private func render(_ state: ViewState<GitHubRepository>) {
        switch state {
        case .loaded(let repo):
            apply(repo)
        case .error:
            // Keep cached row visible; we don't blank the screen for a
            // transient `/repos` failure.
            apply(viewModel.repository)
        case .idle, .loading, .empty:
            apply(viewModel.repository)
        }
    }

    private func apply(_ repo: GitHubRepository) {
        title = repo.fullName
        avatarView.configure(url: repo.owner.avatarUrl, size: 56)
        nameLabel.text = repo.fullName
        ownerLabel.text = "@\(repo.owner.login)"

        let description = repo.description?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        descriptionLabel.text = description.isEmpty ? L10n.detailNoDescription : description

        if let lang = repo.language, !lang.isEmpty {
            languageBadge.configure(systemImage: "circle.fill", value: lang, tint: .systemBlue)
            languageBadge.isHidden = false
        } else {
            languageBadge.isHidden = true
        }
        starsBadge.configure(systemImage: "star.fill",
                             value: CompactNumberFormatter.string(from: repo.stargazersCount),
                             tint: .systemYellow)
        forksBadge.configure(systemImage: "tuningfork",
                             value: CompactNumberFormatter.string(from: repo.forksCount))
        if let issues = repo.openIssuesCount {
            issuesBadge.configure(systemImage: "exclamationmark.bubble",
                                  value: CompactNumberFormatter.string(from: issues))
            issuesBadge.isHidden = false
        } else {
            issuesBadge.isHidden = true
        }

        if let topics = repo.topics, !topics.isEmpty {
            topicsLabel.text = topics.map { "#\($0)" }.joined(separator: "  ")
            topicsLabel.isHidden = false
        } else {
            topicsLabel.isHidden = true
        }

        var dateFragments: [String] = []
        if let created = repo.createdAt {
            dateFragments.append("\(L10n.detailCreated) \(RelativeDateFormatterUtil.string(from: created))")
        }
        if let updated = repo.updatedAt {
            dateFragments.append("\(L10n.repoUpdated) \(RelativeDateFormatterUtil.string(from: updated))")
        }
        if dateFragments.isEmpty {
            datesLabel.isHidden = true
        } else {
            datesLabel.text = dateFragments.joined(separator: " · ")
            datesLabel.isHidden = false
        }

        openOnGitHubButton.isHidden = (repo.htmlUrl == nil)
    }

    @objc private func didTapOpenOnGitHub() {
        guard let url = viewModel.repository.htmlUrl else { return }
        let safari = SFSafariViewController(url: url)
        present(safari, animated: true)
    }
}
