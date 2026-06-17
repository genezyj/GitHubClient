//
//  RepositoryDetailViewController.swift
//  GitHubClient
//

import SafariServices
import UIKit

final class RepositoryDetailViewController: UIViewController {

    private let viewModel: RepositoryDetailViewModel
    private let authService: AuthServiceProtocol

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
    private let breadcrumbScrollView = UIScrollView()
    private let breadcrumbStack = UIStackView()
    private let directoryStatusLabel = UILabel()
    private let directoryStack = UIStackView()
    private var starButton: UIBarButtonItem?

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

    init(viewModel: RepositoryDetailViewModel, authService: AuthServiceProtocol) {
        self.viewModel = viewModel
        self.authService = authService
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = viewModel.path.isEmpty
            ? viewModel.repository.fullName
            : (viewModel.path as NSString).lastPathComponent
        navigationItem.largeTitleDisplayMode = .never
        // The left bar button should always be a plain back chevron, never the
        // (potentially long) directory path of the previous screen.
        navigationItem.backButtonDisplayMode = .minimal
        setupViews()
        setupStarButton()
        bindViewModel()
        viewModel.load()
        viewModel.loadStarStateIfAuthenticated(isLoggedIn: authService.isLoggedIn)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        viewModel.loadStarStateIfAuthenticated(isLoggedIn: authService.isLoggedIn)
    }

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
        // Fill the visible width on iPhone, cap at 700pt on iPad. The equal-width
        // preference sits just below `.required` so it beats the subviews'
        // content compression resistance (`.defaultHigh`) — otherwise the two
        // tie and the layout is ambiguous, intermittently resolving to an
        // over-wide container that gets centered and clipped on both edges
        // (the awesome-ios bug). A *required* upper bound ties the content to
        // the visible frame as a hard guarantee it can never overflow sideways.
        let widthConstraint = contentContainer.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        widthConstraint.priority = .required - 1
        NSLayoutConstraint.activate([
            contentContainer.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentContainer.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentContainer.centerXAnchor.constraint(equalTo: scrollView.frameLayoutGuide.centerXAnchor),
            widthConstraint,
            contentContainer.widthAnchor.constraint(lessThanOrEqualTo: scrollView.frameLayoutGuide.widthAnchor),
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

        setupBreadcrumb()

        directoryStatusLabel.font = .preferredFont(forTextStyle: .footnote)
        directoryStatusLabel.textColor = .secondaryLabel
        directoryStatusLabel.numberOfLines = 0
        directoryStatusLabel.isHidden = true

        directoryStack.axis = .vertical
        directoryStack.spacing = 8

        for view in [
            header,
            descriptionLabel,
            statsRow,
            topicsLabel,
            datesLabel,
            openOnGitHubButton,
            makeDivider(),
            breadcrumbScrollView,
            directoryStatusLabel,
            directoryStack
        ] {
            stack.addArrangedSubview(view)
        }
    }

    // MARK: Breadcrumb

    private func setupBreadcrumb() {
        breadcrumbScrollView.showsHorizontalScrollIndicator = false
        breadcrumbScrollView.translatesAutoresizingMaskIntoConstraints = false

        breadcrumbStack.axis = .horizontal
        breadcrumbStack.alignment = .center
        breadcrumbStack.spacing = 4
        breadcrumbStack.translatesAutoresizingMaskIntoConstraints = false
        breadcrumbScrollView.addSubview(breadcrumbStack)

        NSLayoutConstraint.activate([
            breadcrumbStack.topAnchor.constraint(equalTo: breadcrumbScrollView.contentLayoutGuide.topAnchor),
            breadcrumbStack.bottomAnchor.constraint(equalTo: breadcrumbScrollView.contentLayoutGuide.bottomAnchor),
            breadcrumbStack.leadingAnchor.constraint(equalTo: breadcrumbScrollView.contentLayoutGuide.leadingAnchor),
            breadcrumbStack.trailingAnchor.constraint(equalTo: breadcrumbScrollView.contentLayoutGuide.trailingAnchor),
            breadcrumbStack.heightAnchor.constraint(equalTo: breadcrumbScrollView.frameLayoutGuide.heightAnchor)
        ])

        buildBreadcrumb()
    }

    /// Builds a `[repo] / [folder] / [folder]` trail where every ancestor
    /// segment is a button that pops back to that directory.
    private func buildBreadcrumb() {
        breadcrumbStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        var segments: [(title: String, path: String)] = [(viewModel.repository.name, "")]
        var accumulated = ""
        for component in viewModel.path.split(separator: "/", omittingEmptySubsequences: true) {
            accumulated = accumulated.isEmpty ? String(component) : accumulated + "/" + component
            segments.append((String(component), accumulated))
        }

        for (index, segment) in segments.enumerated() {
            if index > 0 {
                breadcrumbStack.addArrangedSubview(makeBreadcrumbSeparator())
            }
            let isCurrent = index == segments.count - 1
            breadcrumbStack.addArrangedSubview(
                makeBreadcrumbSegment(title: segment.title, path: segment.path, isCurrent: isCurrent)
            )
        }

        // Flexible trailing spacer: when the trail is narrower than the scroll
        // view, this absorbs the slack so the pills/separators stay tightly
        // left-packed instead of the low-hugging "/" separators stretching.
        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        spacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        breadcrumbStack.addArrangedSubview(spacer)
    }

    private func makeBreadcrumbSegment(title: String, path: String, isCurrent: Bool) -> UIView {
        let button = UIButton(type: .system)
        if #available(iOS 15.0, *) {
            // Ancestors are tinted/bordered pills (tappable); the current
            // directory is a filled "you are here" pill that doesn't navigate.
            var config: UIButton.Configuration = isCurrent ? .gray() : .bordered()
            config.title = title
            config.cornerStyle = .capsule
            config.buttonSize = .small
            config.baseForegroundColor = isCurrent ? .label : .systemBlue
            config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
                var outgoing = incoming
                outgoing.font = .preferredFont(forTextStyle: .subheadline)
                return outgoing
            }
            button.configuration = config
        } else {
            button.setTitle(title, for: .normal)
            button.titleLabel?.font = .preferredFont(forTextStyle: .subheadline)
            button.contentEdgeInsets = UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)
            button.layer.cornerRadius = 14
            button.layer.cornerCurve = .continuous
            button.layer.borderWidth = 1
            button.layer.borderColor = (isCurrent ? UIColor.separator : UIColor.systemBlue).cgColor
            button.backgroundColor = isCurrent ? .secondarySystemBackground : .clear
            button.setTitleColor(isCurrent ? .label : .systemBlue, for: .normal)
        }
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
        button.setContentHuggingPriority(.required, for: .horizontal)
        if isCurrent {
            // Keeps full-color appearance (vs. `isEnabled = false`, which dims it)
            // while not responding to taps.
            button.isUserInteractionEnabled = false
        } else {
            button.addAction(UIAction { [weak self] _ in
                self?.navigateToBreadcrumb(path: path)
            }, for: .touchUpInside)
        }
        return button
    }

    private func makeBreadcrumbSeparator() -> UIView {
        let label = UILabel()
        label.text = "/"
        label.font = .preferredFont(forTextStyle: .subheadline)
        label.textColor = .tertiaryLabel
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        // Never let the separator stretch to fill slack — that produced a gap
        // before the following pill.
        label.setContentHuggingPriority(.required, for: .horizontal)
        return label
    }

    /// Pops to the already-pushed directory matching `path`. Because the user
    /// reaches subdirectories by drilling down, every ancestor is still on the
    /// navigation stack.
    private func navigateToBreadcrumb(path: String) {
        guard let nav = navigationController else { return }
        if path == viewModel.path { return }
        let target = nav.viewControllers.last { controller in
            (controller as? RepositoryDetailViewController)?.viewModel.path == path
        }
        if let target {
            nav.popToViewController(target, animated: true)
        }
    }

    private func setupStarButton() {
        let item = UIBarButtonItem(
            image: UIImage(systemName: "star"),
            style: .plain,
            target: self,
            action: #selector(didTapStar)
        )
        navigationItem.rightBarButtonItem = item
        starButton = item
    }

    private func bindViewModel() {
        viewModel.onStateChange = { [weak self] state in
            self?.render(state)
        }
        viewModel.onContentsStateChange = { [weak self] state in
            self?.renderContents(state)
        }
        viewModel.onStarStateChange = { [weak self] isStarred, isToggling in
            self?.renderStar(isStarred: isStarred, isToggling: isToggling)
        }
        viewModel.onStarError = { [weak self] error in
            self?.presentErrorAlert(message: error.localizedMessage)
        }
    }

    private func render(_ state: ViewState<GitHubRepository>) {
        switch state {
        case .loaded(let repo):
            apply(repo)
        case .error:
            apply(viewModel.repository)
        case .idle, .loading, .empty:
            apply(viewModel.repository)
        }
    }

    private func apply(_ repo: GitHubRepository) {
        if viewModel.path.isEmpty {
            title = repo.fullName
        }
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
        datesLabel.text = dateFragments.joined(separator: " · ")
        datesLabel.isHidden = dateFragments.isEmpty
        openOnGitHubButton.isHidden = (repo.htmlUrl == nil)
    }

    private func renderContents(_ state: ViewState<[RepositoryContent]>) {
        directoryStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        switch state {
        case .idle:
            directoryStatusLabel.isHidden = true
        case .loading:
            directoryStatusLabel.text = L10n.commonLoading
            directoryStatusLabel.isHidden = false
        case .empty:
            directoryStatusLabel.text = L10n.repoBrowserEmpty
            directoryStatusLabel.isHidden = false
        case .error(let appError):
            directoryStatusLabel.text = appError.localizedMessage
            directoryStatusLabel.isHidden = false
            directoryStack.addArrangedSubview(makeRetryButton())
        case .loaded(let items):
            directoryStatusLabel.isHidden = true
            items.forEach { directoryStack.addArrangedSubview(makeContentRow(for: $0)) }
        }
    }

    private func renderStar(isStarred: Bool, isToggling: Bool) {
        starButton?.image = UIImage(systemName: isStarred ? "star.fill" : "star")
        starButton?.tintColor = isStarred ? .systemYellow : nil
        starButton?.isEnabled = !isToggling
    }

    private func makeContentRow(for item: RepositoryContent) -> UIControl {
        let row = RepositoryContentRowView()
        row.configure(item: item)
        row.addAction(UIAction { [weak self] _ in
            self?.open(item)
        }, for: .touchUpInside)
        return row
    }

    private func open(_ item: RepositoryContent) {
        if item.isDirectory {
            let child = RepositoryDetailViewController(
                viewModel: viewModel.childViewModel(for: item),
                authService: authService
            )
            navigationController?.pushViewController(child, animated: true)
        } else if item.isFile {
            let file = RepositoryFileViewController(viewModel: viewModel.fileViewModel(for: item))
            navigationController?.pushViewController(file, animated: true)
        } else {
            presentErrorAlert(message: L10n.fileUnsupportedPreview(item.name))
        }
    }

    private func makeRetryButton() -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(L10n.errorRetry, for: .normal)
        button.addAction(UIAction { [weak self] _ in self?.viewModel.loadContents() }, for: .touchUpInside)
        return button
    }

    private func makeDivider() -> UIView {
        let divider = UIView()
        divider.backgroundColor = .separator
        divider.translatesAutoresizingMaskIntoConstraints = false
        divider.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale).isActive = true
        return divider
    }

    @objc private func didTapStar() {
        guard authService.isLoggedIn else {
            presentLoginRequiredAlert()
            return
        }
        viewModel.toggleStar()
    }

    private func presentLoginRequiredAlert() {
        let alert = UIAlertController(
            title: L10n.starLoginRequiredTitle,
            message: L10n.starLoginRequiredMessage,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: L10n.commonCancel, style: .cancel))
        alert.addAction(UIAlertAction(title: L10n.profileLoginWithGitHub, style: .default) { [weak self] _ in
            self?.presentLogin()
        })
        present(alert, animated: true)
    }

    private func presentLogin() {
        let loginVM = LoginViewModel(authService: authService)
        let loginVC = LoginViewController(viewModel: loginVM)
        loginVC.onDidLogin = { [weak self] in
            self?.dismiss(animated: true) {
                guard let self else { return }
                self.viewModel.loadStarStateIfAuthenticated(isLoggedIn: self.authService.isLoggedIn)
            }
        }
        let nav = UINavigationController(rootViewController: loginVC)
        nav.modalPresentationStyle = .formSheet
        present(nav, animated: true)
    }

    @objc private func didTapOpenOnGitHub() {
        guard let url = viewModel.repository.htmlUrl else { return }
        present(SFSafariViewController(url: url), animated: true)
    }

    private func presentErrorAlert(message: String) {
        let alert = UIAlertController(title: L10n.errorTitle, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: L10n.commonOK, style: .default))
        present(alert, animated: true)
    }
}

private final class RepositoryContentRowView: UIControl {

    private let iconView = UIImageView()
    private let nameLabel = UILabel()
    private let detailLabel = UILabel()
    private let chevronView = UIImageView(image: UIImage(systemName: "chevron.right"))

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupViews() {
        backgroundColor = .secondarySystemBackground
        layer.cornerRadius = 10
        layer.cornerCurve = .continuous

        iconView.tintColor = .secondaryLabel
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false

        nameLabel.font = .preferredFont(forTextStyle: .body)
        nameLabel.textColor = .label
        nameLabel.numberOfLines = 1

        detailLabel.font = .preferredFont(forTextStyle: .caption1)
        detailLabel.textColor = .secondaryLabel
        detailLabel.numberOfLines = 1

        chevronView.tintColor = .tertiaryLabel
        chevronView.setContentHuggingPriority(.required, for: .horizontal)

        let textStack = UIStackView(arrangedSubviews: [nameLabel, detailLabel])
        textStack.axis = .vertical
        textStack.spacing = 2

        let row = UIStackView(arrangedSubviews: [iconView, textStack, chevronView])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 12
        row.isUserInteractionEnabled = false
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)

        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 24),
            iconView.heightAnchor.constraint(equalToConstant: 24),
            row.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            row.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12)
        ])
    }

    func configure(item: RepositoryContent) {
        nameLabel.text = item.name
        switch item.type {
        case .dir:
            iconView.image = UIImage(systemName: "folder")
            detailLabel.text = L10n.repoBrowserFolder
            chevronView.isHidden = false
        case .file:
            iconView.image = UIImage(systemName: "doc.text")
            detailLabel.text = item.size.map {
                ByteCountFormatter.string(fromByteCount: Int64($0), countStyle: .file)
            } ?? L10n.repoBrowserFile
            chevronView.isHidden = false
        case .symlink:
            iconView.image = UIImage(systemName: "link")
            detailLabel.text = L10n.repoBrowserUnsupportedItem
            chevronView.isHidden = true
        case .submodule:
            iconView.image = UIImage(systemName: "shippingbox")
            detailLabel.text = L10n.repoBrowserUnsupportedItem
            chevronView.isHidden = true
        case .unknown:
            iconView.image = UIImage(systemName: "questionmark.square")
            detailLabel.text = L10n.repoBrowserUnsupportedItem
            chevronView.isHidden = true
        }
        accessibilityLabel = [item.name, detailLabel.text].compactMap { $0 }.joined(separator: ", ")
    }
}
