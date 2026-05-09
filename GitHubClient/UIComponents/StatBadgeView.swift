//
//  StatBadgeView.swift
//  GitHubClient
//
//  Tiny "icon + value" pill used by `RepositoryCardView` (stars / forks) and
//  `RepositoryDetailViewController` (open issues etc.).
//

import UIKit

final class StatBadgeView: UIView {

    private let iconView = UIImageView()
    private let valueLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupViews() {
        iconView.contentMode = .scaleAspectFit
        iconView.tintColor = .secondaryLabel
        iconView.setContentHuggingPriority(.required, for: .horizontal)

        valueLabel.font = .preferredFont(forTextStyle: .caption1)
        valueLabel.textColor = .secondaryLabel
        valueLabel.numberOfLines = 1

        let stack = UIStackView(arrangedSubviews: [iconView, valueLabel])
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 14),
            iconView.heightAnchor.constraint(equalToConstant: 14),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    /// Configure with a system image name and a pre-formatted value.
    func configure(systemImage: String, value: String, tint: UIColor = .secondaryLabel) {
        iconView.image = UIImage(systemName: systemImage)
        iconView.tintColor = tint
        valueLabel.text = value
    }
}
