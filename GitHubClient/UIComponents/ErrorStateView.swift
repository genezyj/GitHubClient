//
//  ErrorStateView.swift
//  GitHubClient
//

import UIKit

final class ErrorStateView: UIView {

    var onRetry: (() -> Void)?

    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let messageLabel = UILabel()
    private let retryButton: UIButton = {
        if #available(iOS 15.0, *) {
            return UIButton(configuration: .filled(), primaryAction: nil)
        }
        return UIButton(type: .system)
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupViews() {
        backgroundColor = .systemBackground

        iconView.image = UIImage(systemName: "exclamationmark.triangle")
        iconView.tintColor = .systemOrange
        iconView.contentMode = .scaleAspectFit

        titleLabel.font = .preferredFont(forTextStyle: .headline)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0

        messageLabel.font = .preferredFont(forTextStyle: .subheadline)
        messageLabel.textColor = .secondaryLabel
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0

        retryButton.addTarget(self, action: #selector(didTapRetry), for: .touchUpInside)
        retryButton.setTitle(L10n.errorRetry, for: .normal)

        let stack = UIStackView(arrangedSubviews: [iconView, titleLabel, messageLabel, retryButton])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 56),
            iconView.heightAnchor.constraint(equalToConstant: 56),
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -24)
        ])
    }

    func configure(title: String, message: String, retryTitle: String = L10n.errorRetry) {
        titleLabel.text = title
        messageLabel.text = message
        retryButton.setTitle(retryTitle, for: .normal)
    }

    @objc private func didTapRetry() {
        onRetry?()
    }
}
