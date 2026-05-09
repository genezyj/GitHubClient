//
//  RepositoryListCell.swift
//  GitHubClient
//
//  Shared table-view cell that hosts a `RepositoryCardView`. Used by both
//  Home and Search.
//

import UIKit

final class RepositoryListCell: UITableViewCell {

    static let reuseIdentifier = "RepositoryListCell"

    private let card = RepositoryCardView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .default

        card.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(card)
        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            card.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func prepareForReuse() {
        super.prepareForReuse()
        card.reset()
    }

    func configure(with repo: GitHubRepository) {
        card.configure(with: repo)
    }
}
