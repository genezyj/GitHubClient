//
//  RepositoryFileViewController.swift
//  GitHubClient
//

import Kingfisher
import SafariServices
import UIKit
import WebKit

final class RepositoryFileViewController: UIViewController {

    private let viewModel: RepositoryFileViewModel
    private let loadingView = LoadingView()
    private let errorStateView = ErrorStateView()
    private let imageScrollView = UIScrollView()
    private let imageView = UIImageView()
    private var webView: WKWebView?
    private let unsupportedStack = UIStackView()
    private let unsupportedLabel = UILabel()
    private let openOnGitHubButton: UIButton = {
        if #available(iOS 15.0, *) {
            var config = UIButton.Configuration.tinted()
            config.image = UIImage(systemName: "safari")
            config.imagePadding = 8
            return UIButton(configuration: config)
        }
        return UIButton(type: .system)
    }()

    init(viewModel: RepositoryFileViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = viewModel.item.name
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.backButtonDisplayMode = .minimal
        setupViews()
        bindViewModel()
        viewModel.load()
    }

    private func setupViews() {
        setupImageView()
        setupUnsupportedView()

        for overlay in [loadingView, errorStateView] {
            overlay.translatesAutoresizingMaskIntoConstraints = false
            overlay.isHidden = true
            view.addSubview(overlay)
            NSLayoutConstraint.activate([
                overlay.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
                overlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                overlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                overlay.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
        }

        errorStateView.onRetry = { [weak self] in self?.viewModel.load() }
    }

    private func setupImageView() {
        imageScrollView.translatesAutoresizingMaskIntoConstraints = false
        imageScrollView.isHidden = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageScrollView.addSubview(imageView)
        view.addSubview(imageScrollView)
        pinToSafeArea(imageScrollView)
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: imageScrollView.contentLayoutGuide.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: imageScrollView.contentLayoutGuide.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: imageScrollView.contentLayoutGuide.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: imageScrollView.contentLayoutGuide.bottomAnchor),
            imageView.widthAnchor.constraint(equalTo: imageScrollView.frameLayoutGuide.widthAnchor),
            imageView.heightAnchor.constraint(equalTo: imageScrollView.frameLayoutGuide.heightAnchor)
        ])
    }

    private func setupUnsupportedView() {
        unsupportedStack.axis = .vertical
        unsupportedStack.spacing = 16
        unsupportedStack.alignment = .center
        unsupportedStack.translatesAutoresizingMaskIntoConstraints = false
        unsupportedStack.isHidden = true

        unsupportedLabel.font = .preferredFont(forTextStyle: .body)
        unsupportedLabel.textColor = .secondaryLabel
        unsupportedLabel.textAlignment = .center
        unsupportedLabel.numberOfLines = 0

        if #available(iOS 15.0, *) {
            var config = openOnGitHubButton.configuration
            config?.title = L10n.detailOpenOnGitHub
            openOnGitHubButton.configuration = config
        } else {
            openOnGitHubButton.setTitle(L10n.detailOpenOnGitHub, for: .normal)
        }
        openOnGitHubButton.addTarget(self, action: #selector(didTapOpenOnGitHub), for: .touchUpInside)

        unsupportedStack.addArrangedSubview(unsupportedLabel)
        unsupportedStack.addArrangedSubview(openOnGitHubButton)
        view.addSubview(unsupportedStack)
        NSLayoutConstraint.activate([
            unsupportedStack.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor),
            unsupportedStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            unsupportedStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24)
        ])
    }

    private func bindViewModel() {
        viewModel.onStateChange = { [weak self] state in
            self?.render(state)
        }
    }

    private func render(_ state: ViewState<RepositoryFileViewModel.Preview>) {
        hideContentViews()
        switch state {
        case .idle:
            loadingView.isHidden = true
            errorStateView.isHidden = true
        case .loading:
            loadingView.isHidden = false
            errorStateView.isHidden = true
        case .loaded(let preview):
            loadingView.isHidden = true
            errorStateView.isHidden = true
            render(preview)
        case .empty:
            loadingView.isHidden = true
            errorStateView.isHidden = true
            render(.unsupported)
        case .error(let appError):
            loadingView.isHidden = true
            errorStateView.configure(title: L10n.errorTitle, message: appError.localizedMessage)
            errorStateView.isHidden = false
        }
    }

    private func render(_ preview: RepositoryFileViewModel.Preview) {
        switch preview {
        case .markdownHTML(let html), .codeHTML(let html):
            let webView = makeWebViewIfNeeded()
            webView.isHidden = false
            webView.loadHTMLString(html, baseURL: viewModel.item.htmlUrl)
        case .image(let url):
            imageView.kf.setImage(with: url)
            imageScrollView.isHidden = false
        case .unsupported:
            unsupportedLabel.text = L10n.fileUnsupportedPreview(viewModel.item.name)
            openOnGitHubButton.isHidden = viewModel.item.htmlUrl == nil
            unsupportedStack.isHidden = false
        }
    }

    private func makeWebViewIfNeeded() -> WKWebView {
        if let webView { return webView }
        let webView = WKWebView(frame: .zero)
        webView.navigationDelegate = self
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.isHidden = true
        webView.backgroundColor = .systemBackground
        view.addSubview(webView)
        pinToSafeArea(webView)
        self.webView = webView
        return webView
    }

    private func hideContentViews() {
        imageScrollView.isHidden = true
        unsupportedStack.isHidden = true
        webView?.isHidden = true
    }

    private func pinToSafeArea(_ child: UIView) {
        NSLayoutConstraint.activate([
            child.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            child.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            child.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            child.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    @objc private func didTapOpenOnGitHub() {
        guard let url = viewModel.item.htmlUrl else { return }
        present(SFSafariViewController(url: url), animated: true)
    }
}

extension RepositoryFileViewController: WKNavigationDelegate {
    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        guard navigationAction.navigationType == .linkActivated,
              let url = navigationAction.request.url
        else {
            decisionHandler(.allow)
            return
        }
        decisionHandler(.cancel)
        present(SFSafariViewController(url: url), animated: true)
    }
}
