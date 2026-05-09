//
//  LoginViewController.swift
//  GitHubClient
//

import AuthenticationServices
import UIKit

final class LoginViewController: UIViewController {

    private let viewModel: LoginViewModel

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let titleLabel = UILabel()
    private let signInButton: UIButton = {
        if #available(iOS 15.0, *) {
            var config = UIButton.Configuration.filled()
            config.image = UIImage(systemName: "person.crop.circle.badge.checkmark")
            config.imagePadding = 8
            config.imagePlacement = .leading
            config.baseBackgroundColor = .label
            config.baseForegroundColor = .systemBackground
            return UIButton(configuration: config)
        }
        let button = UIButton(type: .system)
        button.backgroundColor = .label
        button.setTitleColor(.systemBackground, for: .normal)
        button.layer.cornerRadius = 10
        return button
    }()
    private let noteLabel = UILabel()
    private let errorLabel = UILabel()
    private let activityIndicator = UIActivityIndicatorView(style: .medium)

    var onDidLogin: (() -> Void)?

    init(viewModel: LoginViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = L10n.loginTitle
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(didTapCancel)
        )
        setupViews()
        bindViewModel()
        showCredentialWarningIfNeeded()
        addUITestingMockLoginButtonIfNeeded()
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

        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(container)
        let widthConstraint = container.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        widthConstraint.priority = .defaultHigh
        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: scrollView.topAnchor),
            container.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            container.centerXAnchor.constraint(equalTo: scrollView.centerXAnchor),
            widthConstraint,
            container.widthAnchor.constraint(lessThanOrEqualToConstant: 600)
        ])

        contentStack.axis = .vertical
        contentStack.spacing = 16
        contentStack.alignment = .fill
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(contentStack)
        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: container.topAnchor, constant: 32),
            contentStack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 24),
            contentStack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -24),
            contentStack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -24)
        ])

        titleLabel.text = L10n.loginHeadline
        titleLabel.font = .preferredFont(forTextStyle: .title2)
        titleLabel.textColor = .label
        titleLabel.numberOfLines = 0

        if #available(iOS 15.0, *) {
            var config = signInButton.configuration ?? UIButton.Configuration.filled()
            config.title = L10n.loginSignInWithGitHub
            signInButton.configuration = config
        } else {
            signInButton.setTitle(L10n.loginSignInWithGitHub, for: .normal)
        }
        signInButton.translatesAutoresizingMaskIntoConstraints = false
        signInButton.addTarget(self, action: #selector(didTapSignIn), for: .touchUpInside)
        signInButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 50).isActive = true

        noteLabel.text = L10n.loginNoteOAuth
        noteLabel.font = .preferredFont(forTextStyle: .footnote)
        noteLabel.textColor = .secondaryLabel
        noteLabel.numberOfLines = 0

        errorLabel.font = .preferredFont(forTextStyle: .footnote)
        errorLabel.textColor = .systemRed
        errorLabel.numberOfLines = 0
        errorLabel.isHidden = true

        activityIndicator.hidesWhenStopped = true

        contentStack.addArrangedSubview(titleLabel)
        contentStack.addArrangedSubview(signInButton)
        contentStack.addArrangedSubview(activityIndicator)
        contentStack.addArrangedSubview(errorLabel)
        contentStack.addArrangedSubview(noteLabel)
    }

    private func bindViewModel() {
        viewModel.onStateChange = { [weak self] state in
            self?.render(state)
        }
    }

    private func showCredentialWarningIfNeeded() {
        guard !viewModel.hasOAuthCredentials else { return }
        errorLabel.text = L10n.loginMissingCredentials
        errorLabel.isHidden = false
        signInButton.isEnabled = false
    }

    private func render(_ state: ViewState<GitHubUser>) {
        switch state {
        case .idle:
            errorLabel.isHidden = true
            activityIndicator.stopAnimating()
            signInButton.isEnabled = viewModel.hasOAuthCredentials
        case .loading:
            errorLabel.isHidden = true
            activityIndicator.startAnimating()
            signInButton.isEnabled = false
        case .loaded:
            activityIndicator.stopAnimating()
            onDidLogin?()
        case .empty:
            activityIndicator.stopAnimating()
            signInButton.isEnabled = viewModel.hasOAuthCredentials
        case .error(let appError):
            activityIndicator.stopAnimating()
            signInButton.isEnabled = viewModel.hasOAuthCredentials
            errorLabel.text = appError.localizedMessage
            errorLabel.isHidden = false
        }
    }

    @objc private func didTapSignIn() {
        guard let anchor = view.window else {
            // Should be impossible while presented, but fail gracefully.
            errorLabel.text = AppError.unknown.localizedMessage
            errorLabel.isHidden = false
            return
        }
        viewModel.signInWithGitHub(presentationAnchor: anchor)
    }

    @objc private func didTapCancel() {
        dismiss(animated: true)
    }

    private func addUITestingMockLoginButtonIfNeeded() {
        guard UITestingConfiguration.enableMockLoginEntryPoint else { return }
        let item = UIBarButtonItem(
            title: "Mock",
            style: .plain,
            target: self,
            action: #selector(didTapUITestingMockLogin)
        )
        item.accessibilityIdentifier = UITestingAccessibilityID.loginMockSignIn
        navigationItem.rightBarButtonItem = item
    }

    @objc private func didTapUITestingMockLogin() {
        do {
            try viewModel.signInUsingUITestingMock()
            // Success path: `render(.loaded)` from `bindViewModel` calls `onDidLogin`.
        } catch {
            errorLabel.text = (error as? AppError)?.localizedMessage ?? AppError.unknown.localizedMessage
            errorLabel.isHidden = false
        }
    }
}
