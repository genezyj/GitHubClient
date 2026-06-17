//
//  ProfileViewController.swift
//  GitHubClient
//

import UIKit

final class ProfileViewController: UIViewController {

    private let viewModel: ProfileViewModel
    private let authService: AuthServiceProtocol
    var onSelectRepository: ((GitHubRepository) -> Void)?

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let contentContainer = UIView()
    private let loadingView = LoadingView()
    private let refreshControl = UIRefreshControl()

    private let avatarView = AvatarImageView()
    private let nameLabel = UILabel()
    private let usernameLabel = UILabel()
    private let bioLabel = UILabel()
    private let statsRow = UIStackView()
    private let metaStack = UIStackView()
    private let primaryButton: UIButton = makeFilledButton(title: "")
    private let secondaryButton: UIButton = makeFilledButton(title: "", tinted: true)
    private let logoutButton: UIButton = makeFilledButton(title: "", destructive: true)
    private let hintLabel = UILabel()
    private let starredTitleLabel = UILabel()
    private let starredStatusLabel = UILabel()
    private let starredStack = UIStackView()

    init(viewModel: ProfileViewModel, authService: AuthServiceProtocol) {
        self.viewModel = viewModel
        self.authService = authService
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = L10n.profileTab
        setupViews()
        bindViewModel()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAuthChange),
            name: .authStateDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleStarredRepositoriesChange),
            name: .starredRepositoriesDidChange,
            object: nil
        )

        // Best-effort silent restore: if a token exists, try to refresh `currentUser`
        // in the background. UI defaults to guest state and updates if it succeeds.
        Task { @MainActor [weak self] in
            guard let self else { return }
            if self.authService.currentUser == nil, self.authService.hasStoredToken {
                _ = try? await self.authService.restoreSession()
                self.viewModel.refresh()
            }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        viewModel.refresh()
    }

    @objc private func handleAuthChange() {
        viewModel.refresh()
    }

    @objc private func handleStarredRepositoriesChange() {
        viewModel.loadStarredRepositories()
    }

    // MARK: Layout

    private func setupViews() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.refreshControl = refreshControl
        refreshControl.addTarget(self, action: #selector(didPullToRefresh), for: .valueChanged)
        view.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        contentContainer.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentContainer)
        // Fill the visible width on iPhone, cap at 700pt on iPad. The equal-width
        // preference sits just below `.required` so it beats the subviews' content
        // compression resistance (`.defaultHigh`) — otherwise the two tie and the
        // layout is ambiguous, intermittently resolving to an over-wide container
        // that gets centered and clipped on both edges (wide starred-repo cards
        // clipped the "Starred 仓库" title and card descriptions). A *required*
        // upper bound guarantees the content can never overflow sideways.
        let widthConstraint = contentContainer.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        widthConstraint.priority = .required - 1
        NSLayoutConstraint.activate([
            contentContainer.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentContainer.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentContainer.centerXAnchor.constraint(equalTo: scrollView.centerXAnchor),
            widthConstraint,
            contentContainer.widthAnchor.constraint(lessThanOrEqualTo: scrollView.widthAnchor),
            contentContainer.widthAnchor.constraint(lessThanOrEqualToConstant: 700)
        ])

        contentStack.axis = .vertical
        contentStack.alignment = .center
        contentStack.spacing = 14
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.addSubview(contentStack)
        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: contentContainer.topAnchor, constant: 24),
            contentStack.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor, constant: 24),
            contentStack.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor, constant: -24),
            contentStack.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor, constant: -32)
        ])

        avatarView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            avatarView.widthAnchor.constraint(equalToConstant: 96),
            avatarView.heightAnchor.constraint(equalToConstant: 96)
        ])

        nameLabel.font = .preferredFont(forTextStyle: .title2)
        nameLabel.textColor = .label
        nameLabel.numberOfLines = 0
        nameLabel.textAlignment = .center

        usernameLabel.font = .preferredFont(forTextStyle: .subheadline)
        usernameLabel.textColor = .secondaryLabel
        usernameLabel.textAlignment = .center

        bioLabel.font = .preferredFont(forTextStyle: .body)
        bioLabel.textColor = .secondaryLabel
        bioLabel.numberOfLines = 0
        bioLabel.textAlignment = .center

        hintLabel.font = .preferredFont(forTextStyle: .footnote)
        hintLabel.textColor = .tertiaryLabel
        hintLabel.numberOfLines = 0
        hintLabel.textAlignment = .center

        starredTitleLabel.font = .preferredFont(forTextStyle: .headline)
        starredTitleLabel.textColor = .label
        starredTitleLabel.textAlignment = .left
        starredTitleLabel.text = L10n.profileStarredRepositories
        starredTitleLabel.isHidden = true

        starredStatusLabel.font = .preferredFont(forTextStyle: .footnote)
        starredStatusLabel.textColor = .secondaryLabel
        starredStatusLabel.numberOfLines = 0
        starredStatusLabel.textAlignment = .center
        starredStatusLabel.isHidden = true

        starredStack.axis = .vertical
        starredStack.spacing = 10
        starredStack.alignment = .fill
        starredStack.isHidden = true

        statsRow.axis = .horizontal
        statsRow.spacing = 16
        statsRow.alignment = .center
        statsRow.distribution = .fillEqually

        metaStack.axis = .vertical
        metaStack.alignment = .center
        metaStack.spacing = 4

        primaryButton.addTarget(self, action: #selector(didTapPrimary), for: .touchUpInside)
        secondaryButton.addTarget(self, action: #selector(didTapSecondary), for: .touchUpInside)
        logoutButton.addTarget(self, action: #selector(didTapLogout), for: .touchUpInside)

        for view in [avatarView, nameLabel, usernameLabel, bioLabel, metaStack, statsRow, primaryButton, secondaryButton, logoutButton, hintLabel, starredTitleLabel, starredStatusLabel, starredStack] {
            contentStack.addArrangedSubview(view)
        }

        for view in [starredTitleLabel, starredStatusLabel, starredStack] {
            view.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                view.leadingAnchor.constraint(equalTo: contentStack.leadingAnchor),
                view.trailingAnchor.constraint(equalTo: contentStack.trailingAnchor)
            ])
        }

        // Buttons span the inner width.
        for button in [primaryButton, secondaryButton, logoutButton] {
            button.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                button.leadingAnchor.constraint(equalTo: contentStack.leadingAnchor),
                button.trailingAnchor.constraint(equalTo: contentStack.trailingAnchor),
                button.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
            ])
        }

        loadingView.translatesAutoresizingMaskIntoConstraints = false
        loadingView.isHidden = true
        view.addSubview(loadingView)
        NSLayoutConstraint.activate([
            loadingView.topAnchor.constraint(equalTo: view.topAnchor),
            loadingView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            loadingView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            loadingView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func bindViewModel() {
        viewModel.onStateChange = { [weak self] state in
            self?.render(state)
        }
        viewModel.onStarredStateChange = { [weak self] state in
            self?.renderStarredRepositories(state)
        }
    }

    @objc private func didPullToRefresh() {
        viewModel.refresh()
    }

    // MARK: Render

    private func render(_ state: ViewState<ProfileViewModel.Mode>) {
        switch state {
        case .idle:
            loadingView.isHidden = true
            refreshControl.endRefreshing()
        case .loading:
            loadingView.isHidden = false
        case .empty:
            loadingView.isHidden = true
            refreshControl.endRefreshing()
        case .error(let appError):
            loadingView.isHidden = true
            refreshControl.endRefreshing()
            presentErrorAlert(message: appError.localizedMessage)
        case .loaded(let mode):
            loadingView.isHidden = true
            refreshControl.endRefreshing()
            switch mode {
            case .guest(let canUseBiometrics):
                renderGuest(canUseBiometrics: canUseBiometrics)
            case .loggedIn(let user):
                renderLoggedIn(user: user)
            }
        }
    }

    private func renderGuest(canUseBiometrics: Bool) {
        avatarView.reset()
        nameLabel.text = nil
        nameLabel.isHidden = true
        usernameLabel.text = L10n.profileNotLoggedIn
        usernameLabel.isHidden = false
        bioLabel.isHidden = true
        statsRow.arrangedSubviews.forEach { $0.removeFromSuperview() }
        statsRow.isHidden = true
        metaStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        metaStack.isHidden = true

        primaryButton.isHidden = false
        primaryButton.setTitle(L10n.profileLoginWithGitHub, for: .normal)
        if UITestingConfiguration.isRunningUITests {
            primaryButton.accessibilityIdentifier = UITestingAccessibilityID.profileLoginGitHub
            logoutButton.accessibilityIdentifier = nil
        }

        secondaryButton.isHidden = !canUseBiometrics
        secondaryButton.setTitle(L10n.profileLoginWithBiometrics, for: .normal)

        logoutButton.isHidden = true
        hintLabel.text = L10n.profileLoginHint
        hintLabel.isHidden = false
        renderStarredRepositories(.idle)
    }

    private func renderLoggedIn(user: GitHubUser) {
        avatarView.configure(url: user.avatarUrl, size: 96)
        nameLabel.text = user.name ?? user.login
        nameLabel.isHidden = false
        usernameLabel.text = "@\(user.login)"
        usernameLabel.isHidden = false
        bioLabel.text = user.bio
        bioLabel.isHidden = (user.bio?.isEmpty ?? true)

        statsRow.arrangedSubviews.forEach { $0.removeFromSuperview() }
        statsRow.addArrangedSubview(makeStatView(value: user.publicRepos, title: L10n.profileRepos))
        statsRow.addArrangedSubview(makeStatView(value: user.followers, title: L10n.profileFollowers))
        statsRow.addArrangedSubview(makeStatView(value: user.following, title: L10n.profileFollowing))
        statsRow.isHidden = false

        metaStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        if let location = user.location, !location.isEmpty {
            metaStack.addArrangedSubview(makeMetaLabel(systemName: "mappin.and.ellipse", text: location))
        }
        if let blog = user.blog, !blog.isEmpty {
            metaStack.addArrangedSubview(makeMetaLabel(systemName: "link", text: blog))
        }
        metaStack.isHidden = metaStack.arrangedSubviews.isEmpty

        primaryButton.isHidden = true
        secondaryButton.isHidden = true
        logoutButton.isHidden = false
        logoutButton.setTitle(L10n.profileLogout, for: .normal)
        if UITestingConfiguration.isRunningUITests {
            logoutButton.accessibilityIdentifier = UITestingAccessibilityID.profileLogout
            primaryButton.accessibilityIdentifier = nil
        }
        hintLabel.isHidden = true
    }

    private func renderStarredRepositories(_ state: ViewState<[GitHubRepository]>) {
        starredStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        guard authService.isLoggedIn else {
            starredTitleLabel.isHidden = true
            starredStatusLabel.isHidden = true
            starredStack.isHidden = true
            return
        }

        starredTitleLabel.isHidden = false
        switch state {
        case .idle:
            starredStatusLabel.isHidden = true
            starredStack.isHidden = true
        case .loading:
            starredStatusLabel.text = L10n.commonLoading
            starredStatusLabel.isHidden = false
            starredStack.isHidden = true
        case .empty:
            starredStatusLabel.text = L10n.profileNoStarredRepositories
            starredStatusLabel.isHidden = false
            starredStack.isHidden = true
        case .error(let appError):
            starredStatusLabel.text = appError.localizedMessage
            starredStatusLabel.isHidden = false
            starredStack.addArrangedSubview(makeStarredRetryButton())
            starredStack.isHidden = false
        case .loaded(let repos):
            starredStatusLabel.isHidden = true
            repos.forEach { starredStack.addArrangedSubview(makeStarredRow(for: $0)) }
            starredStack.isHidden = repos.isEmpty
        }
    }

    // MARK: Actions

    @objc private func didTapPrimary() {
        let loginVM = LoginViewModel(authService: authService)
        let loginVC = LoginViewController(viewModel: loginVM)
        loginVC.onDidLogin = { [weak self] in
            self?.dismiss(animated: true) {
                self?.viewModel.refresh()
            }
        }
        let nav = UINavigationController(rootViewController: loginVC)
        nav.modalPresentationStyle = .formSheet
        present(nav, animated: true)
    }

    @objc private func didTapSecondary() {
        viewModel.authenticateWithBiometricsAndRestoreSession()
    }

    @objc private func didTapLogout() {
        let alert = UIAlertController(
            title: L10n.profileLogoutConfirmTitle,
            message: L10n.profileLogoutConfirmMessage,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: L10n.commonCancel, style: .cancel))
        alert.addAction(UIAlertAction(title: L10n.profileLogoutSignOutOnly, style: .default) { [weak self] _ in
            self?.viewModel.logout()
        })
        alert.addAction(UIAlertAction(title: L10n.profileLogoutRemoveCredentials, style: .destructive) { [weak self] _ in
            self?.viewModel.revokeStoredLogin()
        })
        present(alert, animated: true)
    }

    private func presentErrorAlert(message: String) {
        let alert = UIAlertController(title: L10n.errorTitle, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: L10n.commonOK, style: .default))
        present(alert, animated: true)
    }

    // MARK: Helpers

    private func makeStatView(value: Int, title: String) -> UIView {
        let valueLabel = UILabel()
        valueLabel.font = .preferredFont(forTextStyle: .title3)
        valueLabel.textColor = .label
        valueLabel.textAlignment = .center
        valueLabel.text = CompactNumberFormatter.string(from: value)

        let titleLabel = UILabel()
        titleLabel.font = .preferredFont(forTextStyle: .caption1)
        titleLabel.textColor = .secondaryLabel
        titleLabel.textAlignment = .center
        titleLabel.text = title

        let stack = UIStackView(arrangedSubviews: [valueLabel, titleLabel])
        stack.axis = .vertical
        stack.spacing = 2
        stack.alignment = .center
        return stack
    }

    private func makeMetaLabel(systemName: String, text: String) -> UILabel {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .footnote)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        let attachment = NSTextAttachment(image: UIImage(systemName: systemName) ?? UIImage())
        let result = NSMutableAttributedString(attachment: attachment)
        result.append(NSAttributedString(string: " " + text))
        label.attributedText = result
        return label
    }

    private func makeStarredRow(for repo: GitHubRepository) -> UIControl {
        let row = RepositoryCardControl()
        row.configure(with: repo)
        row.addAction(UIAction { [weak self] _ in
            self?.onSelectRepository?(repo)
        }, for: .touchUpInside)
        return row
    }

    private func makeStarredRetryButton() -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(L10n.errorRetry, for: .normal)
        button.addAction(UIAction { [weak self] _ in
            self?.viewModel.loadStarredRepositories()
        }, for: .touchUpInside)
        return button
    }

    private static func makeFilledButton(title: String, tinted: Bool = false, destructive: Bool = false) -> UIButton {
        if #available(iOS 15.0, *) {
            var config: UIButton.Configuration = tinted ? .tinted() : .filled()
            if destructive {
                config = .filled()
                config.baseBackgroundColor = .systemRed
            }
            config.title = title
            return UIButton(configuration: config)
        } else {
            let button = UIButton(type: .system)
            button.setTitle(title, for: .normal)
            button.backgroundColor = destructive ? .systemRed : .systemBlue
            button.setTitleColor(.white, for: .normal)
            button.layer.cornerRadius = 10
            return button
        }
    }
}

private final class RepositoryCardControl: UIControl {
    private let card = RepositoryCardView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        card.translatesAutoresizingMaskIntoConstraints = false
        card.isUserInteractionEnabled = false
        addSubview(card)
        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: topAnchor),
            card.leadingAnchor.constraint(equalTo: leadingAnchor),
            card.trailingAnchor.constraint(equalTo: trailingAnchor),
            card.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(with repo: GitHubRepository) {
        card.configure(with: repo)
        accessibilityLabel = repo.fullName
    }
}
