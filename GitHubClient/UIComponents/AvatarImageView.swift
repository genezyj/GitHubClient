//
//  AvatarImageView.swift
//  GitHubClient
//
//  Reusable circular avatar component. Remote loading uses Kingfisher; callers
//  still depend only on `configure(url:size:)`.
//

import Kingfisher
import UIKit

final class AvatarImageView: UIView {

    private let imageView = UIImageView()
    private var configuredURL: URL?

    private let placeholder: UIImage = {
        let config = UIImage.SymbolConfiguration(pointSize: 28, weight: .regular)
        return UIImage(systemName: "person.crop.circle.fill", withConfiguration: config)?
            .withTintColor(.systemGray3, renderingMode: .alwaysOriginal)
            ?? UIImage()
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        imageView.layer.cornerRadius = bounds.width / 2.0
    }

    private func setupView() {
        backgroundColor = .clear
        clipsToBounds = false

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.backgroundColor = .secondarySystemBackground
        imageView.image = placeholder
        addSubview(imageView)

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    /// Configure the view with a remote URL and a target size. Caller is
    /// responsible for providing layout constraints; `size` is used purely
    /// for the corner-radius pre-calculation.
    func configure(url: URL?, size: CGFloat) {
        configuredURL = url
        imageView.layer.cornerRadius = size / 2.0
        imageView.kf.cancelDownloadTask()

        guard let url else {
            imageView.image = placeholder
            return
        }

        imageView.kf.setImage(
            with: url,
            placeholder: placeholder,
            options: [
                .transition(.fade(0.15)),
                .cacheOriginalImage
            ],
            completionHandler: { [weak self] result in
                guard let self else { return }
                if case .failure = result, self.configuredURL == url {
                    self.imageView.image = self.placeholder
                }
            }
        )
    }

    func reset() {
        configuredURL = nil
        imageView.kf.cancelDownloadTask()
        imageView.image = placeholder
    }
}
