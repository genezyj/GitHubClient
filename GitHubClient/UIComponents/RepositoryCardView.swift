//
//  RepositoryCardView.swift
//  GitHubClient
//
//  Reusable card layout for a single repository. Used by Home and Search.
//

import UIKit

final class RepositoryCardView: UIView {

    private let avatarSize: CGFloat = 40
    let avatarView = AvatarImageView()
    private let nameLabel = UILabel()
    private let ownerLabel = UILabel()
    private let descriptionLabel = UILabel()
    private let languageLabel = UILabel()
    private let starsLabel = UILabel()
    private let forksLabel = UILabel()
    private let updatedLabel = UILabel()
    private let metadataStack = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupViews() {
        backgroundColor = .secondarySystemBackground
        layer.cornerRadius = 12
        layer.cornerCurve = .continuous

        nameLabel.font = .preferredFont(forTextStyle: .headline)
        nameLabel.textColor = .label
        nameLabel.numberOfLines = 1

        ownerLabel.font = .preferredFont(forTextStyle: .subheadline)
        ownerLabel.textColor = .secondaryLabel
        ownerLabel.numberOfLines = 1

        descriptionLabel.font = .preferredFont(forTextStyle: .footnote)
        descriptionLabel.textColor = .secondaryLabel
        descriptionLabel.numberOfLines = 3

        for label in [languageLabel, starsLabel, forksLabel, updatedLabel] {
            label.font = .preferredFont(forTextStyle: .caption1)
            label.textColor = .tertiaryLabel
        }

        metadataStack.axis = .horizontal
        metadataStack.spacing = 12
        metadataStack.alignment = .center
        metadataStack.distribution = .fill
        for label in [languageLabel, starsLabel, forksLabel, updatedLabel] {
            metadataStack.addArrangedSubview(label)
        }
        metadataStack.addArrangedSubview(UIView())

        let headerStack = UIStackView(arrangedSubviews: [nameLabel, ownerLabel])
        headerStack.axis = .vertical
        headerStack.spacing = 2

        let topRow = UIStackView(arrangedSubviews: [avatarView, headerStack])
        topRow.axis = .horizontal
        topRow.spacing = 12
        topRow.alignment = .center
        topRow.translatesAutoresizingMaskIntoConstraints = false

        let mainStack = UIStackView(arrangedSubviews: [topRow, descriptionLabel, metadataStack])
        mainStack.axis = .vertical
        mainStack.spacing = 8
        mainStack.translatesAutoresizingMaskIntoConstraints = false

        avatarView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(mainStack)

        NSLayoutConstraint.activate([
            avatarView.widthAnchor.constraint(equalToConstant: avatarSize),
            avatarView.heightAnchor.constraint(equalToConstant: avatarSize),

            mainStack.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            mainStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            mainStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            mainStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12)
        ])
    }

    func configure(with repo: GitHubRepository) {
        nameLabel.text = repo.name
        ownerLabel.text = repo.owner.login
        descriptionLabel.text = repo.description ?? " "
        descriptionLabel.isHidden = (repo.description?.isEmpty ?? true)
        languageLabel.text = repo.language.map { "● \($0)" }
        languageLabel.isHidden = (repo.language == nil)
        starsLabel.text = "★ \(CompactNumberFormatter.string(from: repo.stargazersCount))"
        forksLabel.text = "⑂ \(CompactNumberFormatter.string(from: repo.forksCount))"
        if let updated = repo.updatedAt {
            updatedLabel.text = "\(L10n.repoUpdated) \(RelativeDateFormatterUtil.string(from: updated))"
            updatedLabel.isHidden = false
        } else {
            updatedLabel.isHidden = true
        }
        avatarView.configure(url: repo.owner.avatarUrl, size: avatarSize)
    }

    func reset() {
        avatarView.reset()
        nameLabel.text = nil
        ownerLabel.text = nil
        descriptionLabel.text = nil
        languageLabel.text = nil
        starsLabel.text = nil
        forksLabel.text = nil
        updatedLabel.text = nil
    }
}
