//
//  AvatarImageView.swift
//  GitHubClient
//
//  Reusable circular avatar component. All remote image loading is funneled
//  through this view so business code never touches the URL session directly.
//

import UIKit

final class AvatarImageView: UIView {

    private let imageView = UIImageView()
    private var currentTask: URLSessionDataTask?
    private var currentURL: URL?

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
        currentTask?.cancel()
        currentTask = nil
        currentURL = url

        imageView.layer.cornerRadius = size / 2.0
        imageView.image = placeholder

        guard let url else { return }

        if let cached = RemoteImageLoader.shared.cachedImage(for: url) {
            imageView.image = cached
            return
        }

        currentTask = RemoteImageLoader.shared.loadImage(from: url) { [weak self] image in
            guard let self, self.currentURL == url else { return }
            self.imageView.image = image ?? self.placeholder
        }
    }

    func reset() {
        currentTask?.cancel()
        currentTask = nil
        currentURL = nil
        imageView.image = placeholder
    }
}
